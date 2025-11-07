# マルチアカウント移行ガイド

このドキュメントは、シングルアカウント構成からAWS Organizationsを使用したマルチアカウント構成への移行手順を説明します。

## 📋 概要

現在の構成: **シングルアカウント（パラメーター変更でマルチアカウント対応可能）**

```
AWS Account: 897167645238
├─ Staging環境（VPC: 10.2.0.0/16）
└─ Production環境（VPC: 10.1.0.0/16）
```

移行後の構成: **マルチアカウント（AWS Organizations）**

```
Management Account
├─ 本番共通系アカウント（niigata-kaigo-prod-common）
│   ├─ CloudTrail（Organization Trail）
│   ├─ AWS Config（Aggregator）
│   └─ VPC（10.1.0.0/16）
├─ 本番アプリ系アカウント（niigata-kaigo-prod-app）
│   ├─ ECS
│   ├─ RDS
│   └─ Cognito
├─ ステージング共通系アカウント（niigata-kaigo-stg-common）
│   └─ VPC（10.2.0.0/16）
└─ ステージングアプリ系アカウント（niigata-kaigo-stg-app）
    ├─ ECS
    ├─ RDS
    └─ Cognito
```

## 🎯 移行の目的

- **GCAS準拠の強化**: 本番/非本番の物理的分離
- **セキュリティ強化**: アカウント境界によるアクセス制御
- **リソース管理の最適化**: 各アカウントで独立したService Quotas

## 📝 前提条件

- [ ] 現在のシングルアカウント構成が稼働中
- [ ] AWS Organizations の使用権限がある
- [ ] 4つの新規AWSアカウントを作成可能
- [ ] ダウンタイムを最小限にする必要がある

## 🚀 移行手順

### Phase 1: AWS Organizations セットアップ

#### 1.1 Management Account の準備

現在のアカウント（897167645238）を Management Account として使用するか、新規作成するかを決定。

**推奨**: 新規 Management Account を作成（セキュリティベストプラクティス）

```bash
# AWS CLI で Organizations 有効化
aws organizations create-organization --feature-set ALL
```

#### 1.2 組織単位（OU）の作成

```bash
# Production OU
aws organizations create-organizational-unit \
  --parent-id r-xxxx \
  --name Production

# Staging OU
aws organizations create-organizational-unit \
  --parent-id r-xxxx \
  --name Staging
```

#### 1.3 メンバーアカウントの作成

```bash
# 本番共通系アカウント
aws organizations create-account \
  --email niigata-kaigo-prod-common@example.com \
  --account-name "niigata-kaigo-prod-common"

# 本番アプリ系アカウント
aws organizations create-account \
  --email niigata-kaigo-prod-app@example.com \
  --account-name "niigata-kaigo-prod-app"

# ステージング共通系アカウント
aws organizations create-account \
  --email niigata-kaigo-stg-common@example.com \
  --account-name "niigata-kaigo-stg-common"

# ステージングアプリ系アカウント
aws organizations create-account \
  --email niigata-kaigo-stg-app@example.com \
  --account-name "niigata-kaigo-stg-app"
```

#### 1.4 Service Control Policies (SCP) の適用

```json
// production-scp.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:DeleteVpc",
        "rds:DeleteDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/AdminRole"
        }
      }
    }
  ]
}
```

### Phase 2: パラメーター変更

#### 2.1 CloudTrail スタックをOrganization Trailに変更

**変更前（シングルアカウント）**:
```json
{
  "ParameterKey": "DeploymentMode",
  "ParameterValue": "single-account"
},
{
  "ParameterKey": "OrganizationId",
  "ParameterValue": ""
}
```

**変更後（マルチアカウント）**:
```json
{
  "ParameterKey": "DeploymentMode",
  "ParameterValue": "multi-account-org"
},
{
  "ParameterKey": "OrganizationId",
  "ParameterValue": "o-xxxxxxxxxx"
},
{
  "ParameterKey": "ManagementAccountId",
  "ParameterValue": "123456789012"
}
```

#### 2.2 デプロイ

```bash
# Management Account で実行
cd infra/cloudformation
./scripts/deploy.sh production 01_audit cloudtrail-stack

# Organization Trail が全アカウントに適用される
```

### Phase 3: インフラの段階的移行

#### 3.1 本番共通系アカウントへの移行

```bash
# 1. VPC スタックをデプロイ（本番共通系アカウント）
export AWS_PROFILE=niigata-kaigo-prod-common
./scripts/deploy.sh production 02_network vpc-core-stack

# 2. Security Groups デプロイ
./scripts/deploy.sh production 03_security security-groups-stack

# 3. KMS デプロイ
./scripts/deploy.sh production 03_security kms-stack
```

#### 3.2 本番アプリ系アカウントへの移行

```bash
# 1. Cognito デプロイ（本番アプリ系アカウント）
export AWS_PROFILE=niigata-kaigo-prod-app
./scripts/deploy.sh production 07_cognito cognito-dynamodb-tables
./scripts/deploy.sh production 07_cognito cognito-lambda-triggers
./scripts/deploy.sh production 07_cognito cognito-user-pool
./scripts/deploy.sh production 07_cognito cognito-identity-pool

# 2. RDS デプロイ
./scripts/deploy.sh production 05_data rds-stack

# 3. ECS デプロイ
./scripts/deploy.sh production 04_compute ecs-stack
```

### Phase 4: データ移行

#### 4.1 RDS データ移行

```bash
# 1. 旧アカウントでスナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier niigata-kaigo-production-mysql \
  --db-snapshot-identifier migration-snapshot-20250107

# 2. スナップショットを新アカウントと共有
aws rds modify-db-snapshot-attribute \
  --db-snapshot-identifier migration-snapshot-20250107 \
  --attribute-name restore \
  --values-to-add 新アカウントID

# 3. 新アカウントでスナップショットから復元
export AWS_PROFILE=niigata-kaigo-prod-app
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier niigata-kaigo-production-mysql \
  --db-snapshot-identifier arn:aws:rds:ap-northeast-1:旧アカウントID:snapshot:migration-snapshot-20250107
```

#### 4.2 S3 データ移行

```bash
# S3 レプリケーションを使用
aws s3api put-bucket-replication \
  --bucket 旧バケット名 \
  --replication-configuration file://replication-config.json
```

### Phase 5: トラフィック切り替え

#### 5.1 Route53 レコード更新

```bash
# Blue-Green デプロイ方式
# 1. 新アカウントのALBにウェイトルーティング（10%）
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-10.json

# 2. 監視・検証

# 3. ウェイトを100%に変更
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-100.json
```

### Phase 6: 旧アカウントのクリーンアップ

```bash
# 1. トラフィックが新アカウントに完全移行したことを確認

# 2. 旧アカウントのスタックを削除
export AWS_PROFILE=old-account
./scripts/delete-all-stacks.sh production

# 3. データバックアップを確認後、リソース削除
```

## 🔍 検証ポイント

### Organization Trail の確認

```bash
# Management Account で確認
aws cloudtrail describe-trails --region ap-northeast-1

# IsOrganizationTrail: true を確認
```

### マルチアカウント通信の確認

```bash
# VPC Peering または Transit Gateway でアカウント間通信を確認
aws ec2 describe-vpc-peering-connections
```

### AWS Config Aggregator の確認

```bash
# Management Account で全アカウントの構成を集約
aws configservice describe-configuration-aggregators
```

## 💰 コスト影響

| 項目 | シングルアカウント | マルチアカウント | 差分 |
|------|------------------|-----------------|------|
| NAT Gateway | $45/月 × 1 = $45 | $45/月 × 4 = $180 | +$135 |
| CloudTrail | $2.00/月 × 1 = $2 | $0（Organization Trail） | -$2 |
| AWS Config | $2.00/月 × 1 = $2 | $2.00/月 × 4 = $8 | +$6 |
| 合計 | $49/月 | $188/月 | +$139/月 |

**推奨コスト削減策**:
- VPC Endpoints の活用（NAT Gateway コスト削減）
- ステージング環境の夜間停止

## 📚 参考資料

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Multi-Account Strategy](https://aws.amazon.com/jp/organizations/getting-started/best-practices/)
- [CloudTrail Organization Trails](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html)

## ⚠️ 注意事項

1. **Organization Trail は Management Account でのみ作成可能**
2. **アカウント間のVPC通信には VPC Peering または Transit Gateway が必要**
3. **IAM Role の信頼関係を各アカウントで設定**
4. **データ移行中はダウンタイムが発生する可能性**

## ✅ 移行後の確認事項

- [ ] Organization Trail がすべてのアカウントでログを記録している
- [ ] AWS Config Aggregator が全アカウントの構成を集約している
- [ ] VPC間通信が正常に動作している
- [ ] アプリケーションが正常に動作している
- [ ] Route53 でトラフィックが新アカウントに向いている
- [ ] 旧アカウントのリソースが削除されている

---

**最終更新**: 2025-01-07
**作成者**: Claude (PM)
