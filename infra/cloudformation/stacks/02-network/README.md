# 02-network スタック

## 概要

ネットワーク基盤スタック（VPC、Subnets、NAT Gateway、Route Tables）を構築します。

## ライフサイクル

**年単位（初回のみ作成、慎重に変更）**

- 初回構築後は、基本的に変更しない
- 変更が必要な場合は、影響範囲を慎重に確認

## スタック構成

このスタックは、以下の4つのネストスタックで構成されています:

| ネストスタック | テンプレート | 説明 | 変更頻度 |
|-------------|------------|------|---------|
| VPCStack | `templates/network/vpc-and-igw.yaml` | VPC + Internet Gateway（密結合） | 年単位 |
| SubnetsStack | `templates/network/subnets.yaml` | Subnets（Public × 2, Private × 2） | 年単位（たまに追加） |
| NATGatewaysStack | `templates/network/nat-gateways.yaml` | NAT Gateway × 2（高額） | 年単位 |
| RouteTablesStack | `templates/network/route-tables.yaml` | Route Tables（Public, Private × 2） | 年単位（たまに変更） |

## パラメータ

### 必須パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| `EnvironmentName` | 環境名（staging / production） | staging |
| `ProjectName` | プロジェクト名 | niigata-kaigo |
| `VPCCidr` | VPC CIDR ブロック | 10.2.0.0/16 |
| `TemplateBucketName` | S3バケット名（ネストスタック用） | niigata-kaigo-cfn-templates-staging |

### オプションパラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| `EnableDnsSupport` | DNS サポート | true |
| `EnableDnsHostnames` | DNS ホスト名 | true |

## デプロイ方法

### 前提条件

1. **S3 バケットの作成**: ネストスタック用のテンプレートを格納するS3バケットが必要
   ```bash
   aws s3 mb s3://niigata-kaigo-cfn-templates-staging --region ap-northeast-1
   ```

2. **テンプレートのアップロード**: `templates/` 配下のYAMLファイルをS3にアップロード
   ```bash
   aws s3 sync infra/cloudformation/templates/ \
     s3://niigata-kaigo-cfn-templates-staging/templates/ \
     --region ap-northeast-1
   ```

### GitHub Actions経由でのデプロイ

```bash
gh workflow run "Network Stack Deployment" \
  -f environment=staging \
  -f template_bucket=niigata-kaigo-cfn-templates-staging
```

### 手動デプロイ（Change Set使用）

```bash
# Change Set作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-staging-02-network-stack \
  --change-set-name network-stack-$(date +%Y%m%d%H%M%S) \
  --change-set-type CREATE \
  --template-body file://infra/cloudformation/stacks/02-network/main.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=staging \
    ParameterKey=ProjectName,ParameterValue=niigata-kaigo \
    ParameterKey=VPCCidr,ParameterValue=10.2.0.0/16 \
    ParameterKey=TemplateBucketName,ParameterValue=niigata-kaigo-cfn-templates-staging \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1

# Change Set確認
aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-staging-02-network-stack \
  --change-set-name network-stack-YYYYMMDDHHMMSS \
  --region ap-northeast-1

# Change Set実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-staging-02-network-stack \
  --change-set-name network-stack-YYYYMMDDHHMMSS \
  --region ap-northeast-1
```

## 出力値

このスタックは、以下の値をExportします（他のスタックから参照可能）:

### VPC

- `niigata-kaigo-staging-VpcId`: VPC ID
- `niigata-kaigo-staging-VpcCidr`: VPC CIDR
- `niigata-kaigo-staging-InternetGatewayId`: Internet Gateway ID

### Subnets

- `niigata-kaigo-staging-PublicSubnet1Id`: Public Subnet 1 ID
- `niigata-kaigo-staging-PublicSubnet2Id`: Public Subnet 2 ID
- `niigata-kaigo-staging-PrivateSubnet1Id`: Private Subnet 1 ID
- `niigata-kaigo-staging-PrivateSubnet2Id`: Private Subnet 2 ID

### NAT Gateways

- `niigata-kaigo-staging-NATGateway1Id`: NAT Gateway 1 ID
- `niigata-kaigo-staging-NATGateway2Id`: NAT Gateway 2 ID

### Route Tables

- `niigata-kaigo-staging-PublicRouteTableId`: Public Route Table ID
- `niigata-kaigo-staging-PrivateRouteTable1Id`: Private Route Table 1 ID
- `niigata-kaigo-staging-PrivateRouteTable2Id`: Private Route Table 2 ID

## 依存関係

### このスタックが依存するスタック

なし（ネットワーク基盤スタックは最初に作成）

### このスタックに依存するスタック

- `04-database` スタック（RDS, ElastiCache）
- `06-compute-base` スタック（ECS Cluster, ALB）
- すべてのアプリケーションスタック

## コスト

### 概算月額コスト（Staging環境）

| リソース | 料金 | 月額コスト |
|---------|------|----------|
| VPC | 無料 | ¥0 |
| Subnets | 無料 | ¥0 |
| Internet Gateway | 無料 | ¥0 |
| NAT Gateway × 2 | $0.045/時間 × 2 | 約 ¥10,000 |
| データ転送（NAT） | $0.045/GB | 使用量次第 |

**合計**: 約 ¥10,000/月 （NAT Gatewayのみ課金）

### コスト削減オプション

- **開発環境**: NAT Gateway を1つに減らす（Single-AZ）→ 約50%削減
- **検証後削除**: 検証完了後、スタックを削除してコスト節約

## 注意事項

### Transit Gateway について

Transit Gateway と Direct Connect は、本番環境では必要ですが、Phase 1では実装を保留しています。

**理由**:
- 高額（Transit Gateway: $50/月 + データ転送料）
- Direct Connect 回線手配が必要（100Mbps × 2回線）
- マルチアカウント構成が前提

**実装時期**: Phase 2 以降（本番環境構築時）

### 削除時の注意

このスタックを削除する場合は、依存するスタックを先に削除してください:

1. アプリケーションスタック削除
2. `06-compute-base` スタック削除
3. `04-database` スタック削除
4. **最後に** `02-network` スタック削除

## 関連ドキュメント

- [設計書: ネットワーク設計](../../../docs/02_設計/インフラ設計/基本設計/01_ネットワーク/)
- [CloudFormation構成設計](../../../docs/02_設計/インフラ設計/基本設計/10_CloudFormation構成/)
- [技術標準: CloudFormation](../../../.claude/docs/40_standards/42_infra/iac/cloudformation.md)
