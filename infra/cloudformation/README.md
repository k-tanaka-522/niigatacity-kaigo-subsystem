# CloudFormation テンプレート

**プロジェクト**: 新潟市介護保険事業所システム
**更新日**: 2025-11-09

---

## 📁 ディレクトリ構造

```
infra/cloudformation/
├── README.md                          # このファイル（全体インデックス）
├── stacks/                            # ライフサイクル別スタック定義（デプロイ単位）⭐
│   ├── 01-audit/                      # 年単位（CloudTrail, AWS Config, GuardDuty）
│   ├── 02-network/                    # 年単位（VPC, Subnets, NAT Gateway, Route Tables, SG）
│   ├── 03-security/                   # 月単位（WAF, Security Hub, KMS）
│   ├── 04-database/                   # 月単位（RDS, ElastiCache）
│   ├── 05-storage/                    # 月単位（S3, CloudFront）
│   ├── 06-compute-base/               # 週単位（ECS Cluster, ALB, ECR）
│   ├── 07-cognito/                    # 月単位（Cognito User Pool, Identity Pool）
│   └── 08-monitoring/                 # 月単位（CloudWatch, SNS）
├── templates/                         # 再利用可能なネストスタック（実体）⭐
│   ├── audit/
│   ├── network/
│   │   ├── vpc-and-igw.yaml
│   │   ├── subnets.yaml
│   │   ├── nat-gateways.yaml
│   │   ├── route-tables.yaml
│   │   └── security-groups/
│   ├── security/
│   ├── compute/
│   ├── database/
│   ├── storage/
│   ├── cognito/
│   └── monitoring/
└── parameters/                        # 環境差分を集約 ⭐
    ├── staging.json                   # Staging 環境パラメーター
    └── production.json                # Production 環境パラメーター
```

---

## 🎯 ファイル分割の3原則

CloudFormation テンプレートは、以下の3原則に基づいて分割しています:

### 原則1: AWS コンソールの分け方
**AWS コンソールで別メニュー → 別ファイル**

### 原則2: ライフサイクル（変更頻度）
**初回のみ作成 vs 頻繁に変更 → 分ける**

| 更新頻度 | リソース例 | スタック |
|---------|----------|---------|
| 年単位 | VPC, Subnet, Route Table | 01-audit, 02-network |
| 月単位 | RDS, ElastiCache, S3 | 03-security, 04-database, 05-storage, 08-monitoring |
| 週単位 | ECS Service, ALB, Auto Scaling | 06-compute-base |

### 原則3: 設定数（増減の可能性）
**1個で固定 vs 継続的に増える → 分ける**

詳細: [docs/02_設計/基本設計/10_CloudFormation構成/cloudformation_structure.md](../../docs/02_設計/基本設計/10_CloudFormation構成/cloudformation_structure.md)

---

## 🚀 デプロイ手順

### 前提条件

1. **AWS CLI インストール済み**
2. **AWS 認証情報設定済み**（`~/.aws/credentials`）
3. **S3 バケット作成済み**（テンプレート保管用）
   - Staging: `niigata-kaigo-cfn-templates-staging`
   - Production: `niigata-kaigo-cfn-templates-production`

### ステップ1: テンプレートを S3 にアップロード

```bash
# Staging 環境
aws s3 sync infra/cloudformation/templates/ \
  s3://niigata-kaigo-cfn-templates-staging/templates/ \
  --region ap-northeast-1

# Production 環境
aws s3 sync infra/cloudformation/templates/ \
  s3://niigata-kaigo-cfn-templates-production/templates/ \
  --region ap-northeast-1
```

### ステップ2: スタックをデプロイ（段階的デプロイ）

**推奨順序**: ライフサイクルの長いスタックから順にデプロイ

#### Staging 環境

```bash
# 1. Network スタック（VPC, Subnets, NAT Gateway, Route Tables, SG）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

./scripts/describe-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>

./scripts/execute-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>

# 2. Database スタック（RDS, ElastiCache）
# 3. Storage スタック（S3, CloudFront）
# 4. Compute Base スタック（ECS Cluster, ALB, ECR）
# ... 以降、順番にデプロイ
```

#### Production 環境

```bash
# Staging で検証後、Production にデプロイ
./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

---

## 📊 スタック一覧

| スタック名 | ライフサイクル | 主要リソース | 依存関係 |
|-----------|--------------|------------|---------|
| **01-audit** | 年単位 | CloudTrail, AWS Config, GuardDuty | なし |
| **02-network** | 年単位 | VPC, Subnets, NAT Gateway, Route Tables, SG | なし |
| **03-security** | 月単位 | WAF, Security Hub, KMS | 02-network |
| **04-database** | 月単位 | RDS MySQL, ElastiCache Redis | 02-network |
| **05-storage** | 月単位 | S3, CloudFront | なし |
| **06-compute-base** | 週単位 | ECS Cluster, ALB, ECR | 02-network, 03-security |
| **07-cognito** | 月単位 | Cognito User Pool, Identity Pool, Lambda Triggers | なし |
| **08-monitoring** | 月単位 | CloudWatch Logs, Alarms, SNS | 全スタック |

---

## 🔗 クロススタック参照（Export/Import）

### Export 命名規則

```
{ProjectName}-{Environment}-{ResourceName}
```

例:
- `niigata-kaigo-staging-VpcId`
- `niigata-kaigo-production-PrivateSubnetIds`

### 主要な Exports

| スタック | Export名 | 説明 |
|---------|---------|------|
| 02-network | `niigata-kaigo-${Environment}-VpcId` | VPC ID |
| 02-network | `niigata-kaigo-${Environment}-PrivateSubnetIds` | Private Subnet IDs（カンマ区切り） |
| 02-network | `niigata-kaigo-${Environment}-ALBSecurityGroupId` | ALB Security Group ID |
| 02-network | `niigata-kaigo-${Environment}-ECSSecurityGroupId` | ECS Security Group ID |
| 06-compute-base | `niigata-kaigo-${Environment}-ECSClusterArn` | ECS Cluster ARN |

---

## 🛠️ よくある変更の対応表

| やりたいこと | 変更対象スタック | 変更対象ファイル | 変更頻度 |
|-----------|--------------|--------------|---------|
| Subnet を追加 | 02-network | templates/network/subnets.yaml | たまに |
| Security Group ルールを追加 | 02-network | templates/network/security-groups/main.yaml | 頻繁 |
| RDS インスタンスサイズ変更 | 04-database | parameters/production.json | たまに |
| ECS Task Definition 更新 | 07-compute-app | templates/compute/ecs-task-*.yaml | 頻繁 |
| CloudWatch Alarm 追加 | 08-monitoring | templates/monitoring/cloudwatch-alarms-*.yaml | たまに |

---

## 🔒 安全性の原則

### Change Sets 必須（dry-run）

本番環境への直接デプロイ（`aws cloudformation deploy`）は**絶対にしない**。

**必須フロー**:
```
1. Change Set 作成（差分確認）
2. Change Set 内容確認（dry-run）
3. ユーザー承認
4. Change Set 実行（本番デプロイ）
```

詳細: [docs/02_設計/基本設計/10_CloudFormation構成/deployment_strategy.md](../../docs/02_設計/基本設計/10_CloudFormation構成/deployment_strategy.md)

---

## 📝 デプロイスクリプト

| スクリプト | 役割 |
|-----------|------|
| `scripts/create-changeset.sh` | Change Set 作成 |
| `scripts/describe-changeset.sh` | Change Set 内容確認 |
| `scripts/execute-changeset.sh` | Change Set 実行 |
| `scripts/rollback.sh` | ロールバック |

---

## 📞 トラブルシューティング

### エラー: `ROLLBACK_COMPLETE`

**原因**: リソース作成失敗

**対処**:
1. CloudWatch Logs でエラー詳細を確認
2. テンプレートを修正
3. スタックを削除して再作成

```bash
# スタック削除
aws cloudformation delete-stack --stack-name <stack-name>

# 削除完了を待つ
aws cloudformation wait stack-delete-complete --stack-name <stack-name>

# 再作成
./scripts/create-changeset.sh <stack-name> <template> <parameters> <environment>
```

### エラー: `Export <name> cannot be deleted as it is in use by <stack>`

**原因**: 他のスタックが Export を参照している

**対処**:
1. 参照している側のスタックを先に削除
2. Export している側のスタックを削除

```bash
# 依存関係の確認
aws cloudformation list-exports

# 参照しているスタックを確認
aws cloudformation list-imports --export-name <export-name>
```

---

## 💰 コスト見積もり

### Staging 環境（月額）:
- NAT Gateway × 2: 約 $70
- RDS db.t3.small: 約 $30
- ECS Fargate: 約 $20
- 合計: 約 $120/月

### Production 環境（月額）:
- NAT Gateway × 2: 約 $70
- RDS db.t3.medium Multi-AZ: 約 $120
- ECS Fargate: 約 $50
- 合計: 約 $240/月

**コスト削減のヒント**:
- Staging 環境の NAT Gateway を1つに削減
- 開発中は不要なスタックを削除

---

## 📚 関連ドキュメント

- [cloudformation_structure.md](../../docs/02_設計/基本設計/10_CloudFormation構成/cloudformation_structure.md) - ファイル分割3原則とディレクトリ構造
- [deployment_strategy.md](../../docs/02_設計/基本設計/10_CloudFormation構成/deployment_strategy.md) - デプロイ戦略と Change Sets 運用
- [stack_lifecycle.md](../../docs/02_設計/基本設計/10_CloudFormation構成/stack_lifecycle.md) - スタックライフサイクル管理
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` - CloudFormation 技術標準
