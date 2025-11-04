# Terraform Infrastructure as Code

新潟市介護保険事業所システムのAWSインフラストラクチャをTerraformで管理します。

## ディレクトリ構成

```
terraform/
├── README.md                    # このファイル
├── .terraform-version           # Terraformバージョン指定
├── backend-configs/             # Backend設定ファイル
│   ├── common.hcl
│   ├── prod.hcl
│   ├── staging.hcl
│   └── operations.hcl
├── modules/                     # 再利用可能なモジュール
│   ├── networking/              # ネットワークモジュール
│   ├── security/                # セキュリティモジュール
│   ├── compute/                 # コンピューティングモジュール
│   ├── database/                # データベースモジュール
│   ├── storage/                 # ストレージモジュール
│   └── monitoring/              # 監視モジュール
└── environments/                # 環境別設定
    ├── common/                  # 共通アカウント
    ├── prod/                    # 本番アカウント
    ├── staging/                 # ステージングアカウント
    └── operations/              # 運用アカウント
```

## 前提条件

### 必須ツール

- [Terraform](https://www.terraform.io/downloads.html) >= 1.6.0
- [tfenv](https://github.com/tfutils/tfenv) (バージョン管理用、推奨)
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [pre-commit](https://pre-commit.com/) (推奨)

### インストール

```bash
# tfenvのインストール (Homebrew)
brew install tfenv

# Terraformのインストール
tfenv install 1.6.0
tfenv use 1.6.0

# AWS CLIのインストール
brew install awscli

# pre-commitのインストール
brew install pre-commit
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

### IAMユーザーを使用 (代替手段)

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

## 初回セットアップ

### 1. State管理用リソースの作成

Terraformを実行する前に、State管理用のS3バケットとDynamoDBテーブルを手動で作成します。

```bash
# management-accountで実行

# S3バケット作成
aws s3 mb s3://terraform-state-niigatacity-kaigo --region ap-northeast-1

# バケットバージョニング有効化
aws s3api put-bucket-versioning \
  --bucket terraform-state-niigatacity-kaigo \
  --versioning-configuration Status=Enabled

# バケット暗号化設定
aws s3api put-bucket-encryption \
  --bucket terraform-state-niigatacity-kaigo \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# パブリックアクセスブロック
aws s3api put-public-access-block \
  --bucket terraform-state-niigatacity-kaigo \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# DynamoDBテーブル作成 (State Lock用)
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

### 2. Secrets Managerに機密情報を作成

RDSパスワードなどの機密情報をSecrets Managerに事前作成します。

```bash
# 本番RDSマスターパスワード
aws secretsmanager create-secret \
  --name prod/db/master-password \
  --secret-string '{"username":"pgadmin","password":"CHANGE_ME_TO_STRONG_PASSWORD"}' \
  --region ap-northeast-1 \
  --profile niigatacity-kaigo-prod

# 本番RDSアプリケーションパスワード
aws secretsmanager create-secret \
  --name prod/db/app-password \
  --secret-string '{"username":"kaigo_app","password":"CHANGE_ME_TO_STRONG_PASSWORD"}' \
  --region ap-northeast-1 \
  --profile niigatacity-kaigo-prod

# ステージングRDSマスターパスワード
aws secretsmanager create-secret \
  --name staging/db/master-password \
  --secret-string '{"username":"pgadmin","password":"CHANGE_ME_TO_STRONG_PASSWORD"}' \
  --region ap-northeast-1 \
  --profile niigatacity-kaigo-staging
```

## Terraform実行手順

### 共通アカウント (common-account) のデプロイ

```bash
cd environments/common

# 初期化
terraform init -backend-config=../../backend-configs/common.hcl

# フォーマットチェック
terraform fmt -check

# バリデーション
terraform validate

# 実行計画確認
terraform plan

# 適用
terraform apply

# 出力確認
terraform output
```

### 本番アカウント (prod-app-account) のデプロイ

```bash
cd environments/prod

# 初期化
terraform init -backend-config=../../backend-configs/prod.hcl

# 実行計画確認
terraform plan

# 適用
terraform apply

# 特定のリソースのみ適用
terraform apply -target=module.vpc

# 出力確認
terraform output
```

### ステージングアカウント (staging-account) のデプロイ

```bash
cd environments/staging

# 初期化
terraform init -backend-config=../../backend-configs/staging.hcl

# 実行計画確認
terraform plan

# 適用
terraform apply
```

## よく使うコマンド

### State操作

```bash
# State一覧表示
terraform state list

# 特定リソースの詳細表示
terraform state show aws_vpc.main

# State Refresh (実際のリソースと同期)
terraform refresh

# リソースをStateから削除 (実際のリソースは削除しない)
terraform state rm aws_instance.example
```

### Import (既存リソースをTerraform管理下に)

```bash
# VPCをインポート
terraform import module.vpc.aws_vpc.main vpc-12345678
```

### Workspace管理 (使用しない)

本プロジェクトでは環境ごとに別ディレクトリとStateを使用するため、Workspaceは使用しません。

### トラブルシューティング

```bash
# Lockの強制解除 (慎重に!)
terraform force-unlock LOCK_ID

# プロバイダーキャッシュクリア
rm -rf .terraform

# 再初期化
terraform init -reconfigure

# デバッグモード有効化
export TF_LOG=DEBUG
terraform plan
```

## リソース削除手順

**警告: 本番環境のリソースを削除する前に、必ずバックアップを確認してください。**

```bash
cd environments/prod

# 削除対象の確認
terraform plan -destroy

# 削除実行
terraform destroy

# 特定のリソースのみ削除
terraform destroy -target=module.test_resource
```

## pre-commitフックの設定

コミット前に自動的にTerraformのフォーマットとバリデーションを実行します。

```bash
# リポジトリルートで実行
cd /path/to/niigatacity-kaigo-subsystem

# pre-commitインストール
pre-commit install

# 手動実行
pre-commit run --all-files
```

## CI/CDでの実行

GitHub Actionsで自動実行されます。詳細は [.github/workflows/](../../.github/workflows/) を参照。

### Pull Request時

- `terraform fmt -check`: フォーマットチェック
- `terraform validate`: バリデーション
- `terraform plan`: 実行計画確認
- 結果をPRにコメント

### mainブランチへのマージ時

- `terraform apply -auto-approve`: 自動適用

## セキュリティ

### 機密情報の取り扱い

- ❌ terraform.tfvarsに機密情報を記載しない
- ❌ GitHubにパスワードをコミットしない
- ✅ Secrets Managerを使用
- ✅ Terraform State内の機密情報はKMS暗号化

### アクセス制御

- State S3バケットへのアクセスはIAMで制限
- MFA必須
- CloudTrailで操作ログ記録

## コスト管理

### コスト見積もり

```bash
# Infraco
stを使用 (推奨)
brew install infracost

cd environments/prod
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > plan.json
infracost breakdown --path plan.json
```

## トラブルシューティング

### よくあるエラー

#### Error: Error locking state

```
Error: Error locking state: ConditionalCheckFailedException
```

**解決策:**

```bash
# 他の実行が完了するまで待つ、または
terraform force-unlock LOCK_ID
```

#### Error: Unsupported Terraform Core version

```
Error: Unsupported Terraform Core version
```

**解決策:**

```bash
# .terraform-versionで指定されたバージョンをインストール
tfenv install
tfenv use
```

## リファレンス

- [Terraform公式ドキュメント](https://www.terraform.io/docs)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraformベストプラクティス](https://www.terraform-best-practices.com/)
- [GCAS準拠ガイド](https://guide.gcas.cloud.go.jp/aws/)

## サポート

問題が発生した場合は、以下を確認してください:

1. [AWS詳細設計書](../../docs/02_design/detailed/01_aws_detailed_design.md)
2. [Terraform設計書](../../docs/02_design/detailed/02_terraform_design.md)
3. GitHubリポジトリのIssues

## ライセンス

このプロジェクトは新潟市介護保険事業所システムの一部であり、内部使用のみを目的としています。
