# Network Stack

## 概要

ネットワーク基盤を構築するスタック。

## ライフサイクル

**年単位** - 初回のみ作成、慎重に変更

## 含まれるリソース

### Nested Stacks:
1. **VPC Stack** - VPC と Internet Gateway
2. **Subnets Stack** - Public/Private Subnets
3. **NAT Gateways Stack** - NAT Gateway × 2（高額リソース）
4. **Route Tables Stack** - ルートテーブル設定
5. **Security Groups Stack** - ALB, ECS, RDS の Security Groups

## デプロイ方法

### Staging 環境

```bash
# Change Set 作成
./scripts/create-changeset.sh \
  niigata-kaigo-staging-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# Change Set 内容確認
./scripts/describe-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>

# Change Set 実行
./scripts/execute-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>
```

### Production 環境

```bash
# Change Set 作成
./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production

# Change Set 内容確認
./scripts/describe-changeset.sh \
  niigata-kaigo-production-network-stack \
  <changeset-name>

# Change Set 実行（メンテナンスウィンドウ内で実施）
./scripts/execute-changeset.sh \
  niigata-kaigo-production-network-stack \
  <changeset-name>
```

## Outputs (Exports)

このスタックは以下の値を Export します（他のスタックから参照可能）:

| Export Name | 説明 | 参照スタック例 |
|------------|------|--------------|
| `niigata-kaigo-${Environment}-VpcId` | VPC ID | 全スタック |
| `niigata-kaigo-${Environment}-PublicSubnetIds` | Public Subnet IDs（カンマ区切り） | ALB, NAT Gateway |
| `niigata-kaigo-${Environment}-PrivateSubnetIds` | Private Subnet IDs（カンマ区切り） | ECS, RDS |
| `niigata-kaigo-${Environment}-ALBSecurityGroupId` | ALB Security Group ID | ALB スタック |
| `niigata-kaigo-${Environment}-ECSSecurityGroupId` | ECS Security Group ID | ECS スタック |
| `niigata-kaigo-${Environment}-RDSSecurityGroupId` | RDS Security Group ID | RDS スタック |

## 変更時の注意事項

1. **Staging で十分検証すること**（最低1週間）
2. **メンテナンスウィンドウ内で実施すること**（第3土曜日 2:00-5:00 JST）
3. **複数人でレビューすること**
4. **ロールバック手順を確認しておくこと**
5. **他のスタックへの影響範囲を確認すること**

## 依存関係

### このスタックが依存するスタック:
なし（初回デプロイ対象）

### このスタックに依存するスタック:
- 03-security（Security Group の Export を参照）
- 04-database（Subnet, Security Group の Export を参照）
- 06-compute-base（Subnet, Security Group の Export を参照）
- 07-compute-app（Subnet の Export を参照）

## トラブルシューティング

### NAT Gateway 作成失敗

**原因**: Elastic IP の上限に達している

**対処**:
```bash
# Elastic IP の上限確認
aws ec2 describe-account-attributes \
  --attribute-names max-elastic-ips \
  --region ap-northeast-1

# 上限緩和申請
# AWS Support Center → Service Quotas → EC2 → Elastic IP addresses
```

### Subnet CIDR 重複エラー

**原因**: CIDR ブロックが重複している

**対処**:
```bash
# parameters/staging.json または production.json の CIDR 設定を確認
# VPC CIDR: 10.0.0.0/16 (production), 10.1.0.0/16 (staging)
# Subnet CIDR: VPC CIDR 内で重複しないように設定
```

## コスト

### 月額概算（Staging）:
- VPC: 無料
- Subnets: 無料
- NAT Gateway × 2: 約 $70（高額）
- Elastic IP × 2: $0（NAT Gateway に紐付け済み）

### 月額概算（Production）:
- VPC: 無料
- Subnets: 無料
- NAT Gateway × 2: 約 $70（高額）
- Elastic IP × 2: $0（NAT Gateway に紐付け済み）

**コスト削減のヒント**:
- Staging 環境では NAT Gateway を1つに削減可能（可用性 < コスト）
- 開発中は NAT Gateway を削除し、必要時のみ作成

## 関連ドキュメント

- [docs/02_設計/基本設計/02_ネットワーク設計.md](../../../../docs/02_設計/基本設計/02_ネットワーク設計/)
- [docs/02_設計/基本設計/10_CloudFormation構成/cloudformation_structure.md](../../../../docs/02_設計/基本設計/10_CloudFormation構成/cloudformation_structure.md)
- [docs/02_設計/基本設計/10_CloudFormation構成/deployment_strategy.md](../../../../docs/02_設計/基本設計/10_CloudFormation構成/deployment_strategy.md)
