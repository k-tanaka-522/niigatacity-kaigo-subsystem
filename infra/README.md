# Infrastructure - Multi-Account CloudFormation

## ディレクトリ構造

```
infra/
├── 共通アカウント/                    # Common Account用のインフラコード
│   └── cloudformation/
│       ├── stacks/
│       │   └── 02-network/
│       │       └── main.yaml          # Transit Gateway + Common VPC
│       ├── templates/
│       │   └── network/
│       │       ├── vpc-and-igw.yaml
│       │       ├── subnets.yaml
│       │       ├── nat-gateways.yaml
│       │       ├── route-tables.yaml
│       │       ├── transit-gateway.yaml
│       │       └── transit-gateway-attachment.yaml
│       └── parameters/
│           ├── dev.json
│           ├── staging.json
│           └── production.json
└── appアカウント/                     # App Account用のインフラコード
    └── cloudformation/
        ├── stacks/
        │   └── 03-network/
        │       └── main.yaml          # App VPC + TGW Attachment
        ├── templates/
        │   └── network/
        │       ├── vpc-and-igw.yaml
        │       ├── subnets.yaml
        │       ├── nat-gateways.yaml
        │       ├── route-tables.yaml
        │       └── transit-gateway-attachment.yaml
        └── parameters/
            ├── dev.json
            ├── staging.json
            └── production.json
```

## 設計原則

### 1. アカウント別の完全分離

各アカウント（共通アカウント、appアカウント）は独立したディレクトリを持ち、以下を含みます:

- `stacks/` - メインスタックファイル
- `templates/` - ネステッドスタック用テンプレート
- `parameters/` - 環境別パラメータファイル

### 2. Transit Gateway の役割

- **共通アカウント**: Transit Gateway を作成し、他のアカウントと共有
- **appアカウント**: 共有された Transit Gateway に接続（Attachment）

### 3. デプロイフロー

#### 初回デプロイ（Dev環境）

```bash
# Step 1: 共通アカウントでTransit Gateway + Common VPCを作成
./scripts/deploy-multi-account.sh common dev

# Step 2: 確認後、実行
./scripts/deploy-multi-account.sh common dev --execute

# Step 3: Transit Gateway IDとRoute Table IDを取得
aws cloudformation describe-stacks \
    --stack-name niigata-kaigo-dev-common-network-stack \
    --region ap-northeast-1 \
    --query 'Stacks[0].Outputs'

# Step 4: appアカウントのパラメータファイルを更新
# infra/appアカウント/cloudformation/parameters/dev.json に
# TransitGatewayId と TransitGatewayRouteTableId を設定

# Step 5: appアカウントでApp VPC + TGW Attachmentを作成
./scripts/deploy-multi-account.sh app dev

# Step 6: 確認後、実行
./scripts/deploy-multi-account.sh app dev --execute
```

#### 更新デプロイ

```bash
# 共通アカウントの更新
./scripts/deploy-multi-account.sh common dev --execute

# appアカウントの更新
./scripts/deploy-multi-account.sh app dev --execute
```

#### ロールバック

```bash
# 共通アカウントのロールバック
./scripts/rollback-multi-account.sh common dev

# appアカウントのロールバック
./scripts/rollback-multi-account.sh app dev
```

## 環境別パラメータ

### 共通アカウント

`infra/共通アカウント/cloudformation/parameters/{environment}.json`

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "niigata-kaigo"
  },
  {
    "ParameterKey": "CommonVPCCidr",
    "ParameterValue": "10.100.0.0/16"
  },
  {
    "ParameterKey": "EnableTransitGateway",
    "ParameterValue": "Yes"
  },
  {
    "ParameterKey": "TemplateBucketName",
    "ParameterValue": "niigata-kaigo-cfn-templates-dev"
  }
]
```

### appアカウント

`infra/appアカウント/cloudformation/parameters/{environment}.json`

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "niigata-kaigo"
  },
  {
    "ParameterKey": "AppVPCCidr",
    "ParameterValue": "10.101.0.0/16"
  },
  {
    "ParameterKey": "TransitGatewayId",
    "ParameterValue": "tgw-xxxxxxxxxxxxxxxxx"
  },
  {
    "ParameterKey": "TransitGatewayRouteTableId",
    "ParameterValue": "tgw-rtb-xxxxxxxxxxxxxxxxx"
  },
  {
    "ParameterKey": "TemplateBucketName",
    "ParameterValue": "niigata-kaigo-cfn-templates-dev"
  }
]
```

## 注意事項

### 1. S3バケットの準備

デプロイ前に、ネステッドスタック用のS3バケットを作成してください:

```bash
# Dev環境用
aws s3 mb s3://niigata-kaigo-cfn-templates-dev --region ap-northeast-1

# Staging環境用
aws s3 mb s3://niigata-kaigo-cfn-templates-staging --region ap-northeast-1

# Production環境用
aws s3 mb s3://niigata-kaigo-cfn-templates-production --region ap-northeast-1
```

### 2. テンプレートのアップロード

デプロイ前に、テンプレートファイルをS3にアップロードしてください:

```bash
# 共通アカウントのテンプレートをアップロード
aws s3 sync infra/共通アカウント/cloudformation/templates/ \
    s3://niigata-kaigo-cfn-templates-dev/共通アカウント/templates/ \
    --region ap-northeast-1

# appアカウントのテンプレートをアップロード
aws s3 sync infra/appアカウント/cloudformation/templates/ \
    s3://niigata-kaigo-cfn-templates-dev/appアカウント/templates/ \
    --region ap-northeast-1
```

### 3. Transit Gateway ID の取得

共通アカウントのデプロイ後、以下のコマンドでTransit Gateway IDを取得してください:

```bash
aws cloudformation describe-stacks \
    --stack-name niigata-kaigo-dev-common-network-stack \
    --region ap-northeast-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
    --output text
```

### 4. マルチアカウント環境でのデプロイ

実際のマルチアカウント環境では、以下の手順を実施してください:

1. 共通アカウントでTransit Gatewayを作成
2. AWS Resource Access Manager (RAM) でTransit Gatewayを共有
3. appアカウントで共有されたTransit Gatewayを受け入れ
4. appアカウントのパラメータファイルにTransit Gateway IDを設定
5. appアカウントでデプロイ

## トラブルシューティング

### Change Set作成失敗

```bash
# エラー詳細を確認
aws cloudformation describe-change-set \
    --stack-name niigata-kaigo-dev-common-network-stack \
    --change-set-name <change-set-name> \
    --region ap-northeast-1

# Change Setを削除
aws cloudformation delete-change-set \
    --stack-name niigata-kaigo-dev-common-network-stack \
    --change-set-name <change-set-name> \
    --region ap-northeast-1
```

### スタック削除

```bash
# 共通アカウントのスタック削除
aws cloudformation delete-stack \
    --stack-name niigata-kaigo-dev-common-network-stack \
    --region ap-northeast-1

# appアカウントのスタック削除
aws cloudformation delete-stack \
    --stack-name niigata-kaigo-dev-app-network-stack \
    --region ap-northeast-1
```

## 参考資料

- [AWS CloudFormation ベストプラクティス](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [Transit Gateway のドキュメント](https://docs.aws.amazon.com/ja_jp/vpc/latest/tgw/)
- [マルチアカウント戦略](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/orgs_introduction.html)
