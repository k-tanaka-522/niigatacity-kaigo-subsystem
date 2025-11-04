# CloudFormation Infrastructure as Code

新潟市介護保険事業所システムのAWSインフラストラクチャをCloudFormationで管理します。

## ディレクトリ構成

```
cloudformation/
├── README.md                    # このファイル
├── templates/                   # 環境別テンプレート
│   ├── common/                  # 共通アカウント
│   ├── prod/                    # 本番アカウント
│   ├── staging/                 # ステージングアカウント
│   └── operations/              # 運用アカウント
└── modules/                     # 再利用可能なモジュール
    ├── networking/              # ネットワークモジュール
    ├── security/                # セキュリティモジュール
    ├── compute/                 # コンピューティングモジュール
    ├── database/                # データベースモジュール
    ├── storage/                 # ストレージモジュール
    └── monitoring/              # 監視モジュール
```

## 前提条件

### 必須ツール

- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) (推奨)
- [rain](https://github.com/aws-cloudformation/rain) (推奨)

### インストール

```bash
# AWS CLIのインストール
brew install awscli

# cfn-lintのインストール
pip install cfn-lint

# rainのインストール (CloudFormation CLI拡張)
brew install rain
```

## AWS認証情報の設定

### IAM Identity Centerを使用 (推奨)

```bash
# AWS CLIでIAM Identity Centerを設定
aws configure sso

# プロファイル名: niigatacity-kaigo-prod
# SSO Start URL: https://your-sso-portal.awsapps.com/start
# SSO Region: ap-northeast-1
# Account ID: 555555555555 (prod-app-account)

# ログイン
aws sso login --profile niigatacity-kaigo-prod

# 環境変数設定
export AWS_PROFILE=niigatacity-kaigo-prod
```

## CloudFormation実行手順

### 共通アカウント (common-account) のデプロイ

```bash
cd templates/common

# バリデーション
aws cloudformation validate-template \
  --template-body file://vpc.yaml

# または cfn-lint使用
cfn-lint vpc.yaml

# スタック作成
aws cloudformation create-stack \
  --stack-name niigatacity-common-vpc \
  --template-body file://vpc.yaml \
  --parameters file://parameters-common.json \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1

# スタック作成状況確認
aws cloudformation describe-stacks \
  --stack-name niigatacity-common-vpc \
  --region ap-northeast-1

# スタックイベント確認
aws cloudformation describe-stack-events \
  --stack-name niigatacity-common-vpc \
  --region ap-northeast-1 \
  --max-items 20
```

### rainを使用したデプロイ (推奨)

```bash
# スタック作成 (インタラクティブ)
rain deploy vpc.yaml niigatacity-common-vpc \
  --params parameters-common.json

# スタック監視
rain watch niigatacity-common-vpc

# スタック削除
rain rm niigatacity-common-vpc
```

### 本番アカウント (prod-app-account) のデプロイ

```bash
cd templates/prod

# スタック作成
aws cloudformation create-stack \
  --stack-name niigatacity-prod-vpc \
  --template-body file://vpc.yaml \
  --parameters file://parameters-prod.json \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1

# Change Set作成 (更新時)
aws cloudformation create-change-set \
  --stack-name niigatacity-prod-vpc \
  --change-set-name update-$(date +%Y%m%d-%H%M%S) \
  --template-body file://vpc.yaml \
  --parameters file://parameters-prod.json \
  --capabilities CAPABILITY_IAM

# Change Set確認
aws cloudformation describe-change-set \
  --stack-name niigatacity-prod-vpc \
  --change-set-name update-20251104-120000

# Change Set実行
aws cloudformation execute-change-set \
  --stack-name niigatacity-prod-vpc \
  --change-set-name update-20251104-120000
```

## よく使うコマンド

### スタック操作

```bash
# スタック一覧表示
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --region ap-northeast-1

# スタック詳細表示
aws cloudformation describe-stacks \
  --stack-name niigatacity-prod-vpc

# スタック出力値取得
aws cloudformation describe-stacks \
  --stack-name niigatacity-prod-vpc \
  --query 'Stacks[0].Outputs'

# スタック削除
aws cloudformation delete-stack \
  --stack-name niigatacity-prod-vpc
```

### ドリフト検出

```bash
# ドリフト検出開始
aws cloudformation detect-stack-drift \
  --stack-name niigatacity-prod-vpc

# ドリフト検出結果確認
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx

# リソース別ドリフト確認
aws cloudformation describe-stack-resource-drifts \
  --stack-name niigatacity-prod-vpc
```

### テンプレート検証

```bash
# AWS CLIでバリデーション
aws cloudformation validate-template \
  --template-body file://vpc.yaml

# cfn-lintで詳細チェック
cfn-lint vpc.yaml

# 全テンプレートを一括チェック
find . -name "*.yaml" -exec cfn-lint {} \;
```

## StackSetsによるマルチアカウント管理

複数のアカウントに同じスタックをデプロイする場合はStackSetsを使用します。

```bash
# StackSet作成
aws cloudformation create-stack-set \
  --stack-set-name niigatacity-security-baseline \
  --template-body file://security-baseline.yaml \
  --capabilities CAPABILITY_IAM

# StackSetインスタンス作成 (複数アカウントにデプロイ)
aws cloudformation create-stack-instances \
  --stack-set-name niigatacity-security-baseline \
  --accounts 555555555555 666666666666 \
  --regions ap-northeast-1
```

## ネステッドスタック

複雑なインフラは複数のテンプレートに分割し、ネステッドスタックとして管理します。

```yaml
# master.yaml
Resources:
  VPCStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3.amazonaws.com/bucket/vpc.yaml
      Parameters:
        VpcCIDR: 10.1.0.0/16
```

## パラメータファイル例

**parameters-prod.json:**

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "VpcCIDR",
    "ParameterValue": "10.1.0.0/16"
  },
  {
    "ParameterKey": "AvailabilityZones",
    "ParameterValue": "ap-northeast-1a,ap-northeast-1c"
  }
]
```

## CI/CD統合

GitHub Actionsで自動デプロイを実行します。詳細は [.github/workflows/](../../.github/workflows/) を参照。

### Pull Request時

- `cfn-lint`: テンプレート検証
- `aws cloudformation validate-template`: AWS検証
- Change Set作成とレビュー

### mainブランチへのマージ時

- Change Set実行 (本番環境は手動承認)

## セキュリティ

### 機密情報の取り扱い

- ❌ パラメータファイルに機密情報を記載しない
- ❌ GitHubにパスワードをコミットしない
- ✅ Secrets Managerを使用
- ✅ 動的参照を活用: `{{resolve:secretsmanager:secret-id:secret-string:json-key}}`

**例:**

```yaml
MasterUserPassword: !Sub '{{resolve:secretsmanager:${Environment}/db/master-password:SecretString:password}}'
```

### アクセス制御

- CloudFormationスタックへのアクセスはIAMで制限
- 本番環境の変更はChange Setレビュー必須
- CloudTrailで操作ログ記録

## コスト管理

### コストタグ

全リソースに以下のタグを付与:

```yaml
Tags:
  - Key: Environment
    Value: !Ref Environment
  - Key: Project
    Value: niigatacity-kaigo
  - Key: ManagedBy
    Value: CloudFormation
  - Key: CostCenter
    Value: IT-Infrastructure
```

### コスト見積もり

```bash
# AWS Cost Explorerで確認
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Project
```

## トラブルシューティング

### よくあるエラー

#### Error: Stack is in ROLLBACK_COMPLETE state

```
Stack [stack-name] is in ROLLBACK_COMPLETE state and can not be updated.
```

**解決策:**

```bash
# スタックを削除して再作成
aws cloudformation delete-stack --stack-name stack-name
```

#### Error: No export named XXX found

```
No export named vpc-id found. Rollback requested by user.
```

**解決策:**

- 依存するスタックを先にデプロイ
- Export名が正しいか確認

### ロールバック無効化 (開発時のみ)

```bash
# ロールバック無効化でスタック作成 (デバッグ用)
aws cloudformation create-stack \
  --stack-name test-stack \
  --template-body file://test.yaml \
  --disable-rollback
```

## ベストプラクティス

1. **Change Setの活用**: 本番環境への変更は必ずChange Setでレビュー
2. **ネステッドスタック**: 大規模なインフラは分割して管理
3. **パラメータ化**: 環境依存の値はパラメータで外部化
4. **タグ付け**: 全リソースに環境・プロジェクトタグを付与
5. **ドリフト検出**: 定期的にドリフト検出を実行
6. **バージョン管理**: S3にテンプレートをバージョニングして保存

## リファレンス

- [CloudFormation公式ドキュメント](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormationテンプレートリファレンス](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [cfn-lint](https://github.com/aws-cloudformation/cfn-lint)
- [rain CLI](https://github.com/aws-cloudformation/rain)
- [GCAS準拠ガイド](https://guide.gcas.cloud.go.jp/aws/)

## サポート

問題が発生した場合は、以下を確認してください:

1. [AWS基本設計書](../../docs/02_design/basic/01_aws_basic_design.md)
2. [AWS詳細設計書](../../docs/02_design/detailed/01_aws_detailed_design.md)
3. [CloudFormation設計書](../../docs/02_design/detailed/02_cloudformation_design.md)
4. GitHubリポジトリのIssues

## ライセンス

このプロジェクトは新潟市介護保険事業所システムの一部であり、内部使用のみを目的としています。
