# CloudFormation Infrastructure

## 概要

新潟市介護保険事業所システムのAWSインフラをCloudFormationで管理します。

## ディレクトリ構成

```
infra/cloudformation/
├── production/                  # 本番環境テンプレート
│   ├── 01_foundation/          # 基盤層（Organizations、IAM）
│   ├── 02_network/             # ネットワーク層（VPC、TGW、Direct Connect）
│   ├── 03_security/            # セキュリティ層（SG、KMS、WAF）
│   ├── 04_compute/             # コンピューティング層（ECS、ALB）
│   ├── 05_data/                # データ層（RDS、ElastiCache）
│   ├── 06_storage/             # ストレージ層（S3、CloudFront）
│   ├── 07_monitoring/          # 監視層（CloudWatch、CloudTrail）
│   ├── 08_backup/              # バックアップ層（AWS Backup）
│   └── 09_dns/                 # DNS層（Route 53）
│
├── staging/                     # ステージング環境テンプレート
│   ├── 02_network/
│   ├── 03_security/
│   ├── 04_compute/
│   ├── 05_data/
│   ├── 06_storage/
│   ├── 07_monitoring/
│   └── 08_backup/
│
├── parameters/                  # パラメータファイル
│   ├── production/             # 本番環境パラメータ
│   └── staging/                # ステージング環境パラメータ
│
├── scripts/                     # デプロイスクリプト
│   ├── deploy.sh               # デプロイメインスクリプト
│   ├── create-changeset.sh     # Change Set作成
│   ├── execute-changeset.sh    # Change Set実行
│   └── validate.sh             # テンプレート検証
│
└── README.md                    # このファイル
```

## ファイル分割3原則

### 1. ライフサイクルで分割
変更頻度が異なるリソースは別スタックに分割

- **VPC（低頻度）**: ほぼ変更しない
- **ECS（高頻度）**: アプリデプロイで頻繁に変更
- **RDS（低頻度）**: 慎重に変更

### 2. 責務で分割
異なる役割を持つリソースは別スタックに分割

- ネットワーク層
- コンピューティング層
- データ層
- セキュリティ層
- 監視層

### 3. 依存関係で分割
依存関係が明確に分離できるものは別スタックに分割

```
VPC → サブネット → Security Group → ECS
```

## デプロイ手順

### 事前準備

1. AWS CLIのインストールと認証設定
```bash
aws configure
```

2. 必要なパラメータをParameters Storeに登録
```bash
# DBパスワードの登録
aws ssm put-parameter \
  --name /niigata-kaigo/production/db/password \
  --value "YourSecurePassword123!" \
  --type SecureString \
  --region ap-northeast-1
```

### デプロイ順序

#### 本番環境

```bash
# 1. Foundation層
./scripts/deploy.sh production 01_foundation iam-roles-stack

# 2. Network層
./scripts/deploy.sh production 02_network vpc-core-stack
./scripts/deploy.sh production 02_network subnets-stack
./scripts/deploy.sh production 02_network route-tables-stack
./scripts/deploy.sh production 02_network nat-gateways-stack
./scripts/deploy.sh production 02_network vpc-endpoints-stack
./scripts/deploy.sh production 02_network vpc-flowlogs-stack
./scripts/deploy.sh production 02_network tgw-core-stack
./scripts/deploy.sh production 02_network tgw-attachments-stack
./scripts/deploy.sh production 02_network tgw-route-tables-stack

# 3. Security層
./scripts/deploy.sh production 03_security sg-alb-stack
./scripts/deploy.sh production 03_security sg-ecs-stack
./scripts/deploy.sh production 03_security sg-rds-stack
./scripts/deploy.sh production 03_security kms-stack
./scripts/deploy.sh production 03_security waf-stack

# 4. Compute層
./scripts/deploy.sh production 04_compute ecr-stack
./scripts/deploy.sh production 04_compute alb-stack
./scripts/deploy.sh production 04_compute ecs-cluster-stack
./scripts/deploy.sh production 04_compute ecs-task-definition-stack
./scripts/deploy.sh production 04_compute ecs-service-stack

# 5. Data層
./scripts/deploy.sh production 05_data rds-subnet-group-stack
./scripts/deploy.sh production 05_data rds-parameter-group-stack
./scripts/deploy.sh production 05_data rds-instance-stack
./scripts/deploy.sh production 05_data elasticache-cluster-stack

# 6. Storage層
./scripts/deploy.sh production 06_storage s3-buckets-stack

# 7. Monitoring層
./scripts/deploy.sh production 07_monitoring sns-topics-stack
./scripts/deploy.sh production 07_monitoring cloudwatch-alarms-stack

# 8. Backup層
./scripts/deploy.sh production 08_backup backup-vault-stack
./scripts/deploy.sh production 08_backup backup-plan-stack
```

#### ステージング環境

```bash
# Network層から開始（Foundation層は本番と共有）
./scripts/deploy.sh staging 02_network vpc-core-stack
./scripts/deploy.sh staging 02_network subnets-stack
# ... 以下同様
```

## Change Setを使った安全なデプロイ

### 1. Change Setの作成

```bash
./scripts/create-changeset.sh production 02_network vpc-core-stack
```

### 2. Change Setのレビュー

AWS Management Consoleまたは以下のコマンドでChange Setの内容を確認:

```bash
aws cloudformation describe-change-set \
  --change-set-name <CHANGESET_NAME> \
  --stack-name <STACK_NAME> \
  --region ap-northeast-1
```

### 3. Change Setの実行

レビュー後、問題がなければ実行:

```bash
./scripts/execute-changeset.sh production 02_network vpc-core-stack <CHANGESET_NAME>
```

## テンプレート検証

デプロイ前にテンプレートの構文を検証:

```bash
./scripts/validate.sh production/02_network/vpc-core-stack.yaml
```

## タグ戦略

すべてのリソースに以下のタグを付与:

| タグキー | タグ値例 | 用途 |
|---------|---------|------|
| Environment | Production, Staging | 環境識別 |
| Project | niigata-kaigo | プロジェクト識別 |
| ManagedBy | CloudFormation | 管理方法 |
| Owner | admin@niigata-city.jp | 責任者 |
| CostCenter | IT-Dept | コスト配分 |

## ベストプラクティス

### 1. DeletionPolicy

重要なデータリソースには`Retain`を設定:

```yaml
Resources:
  RDSInstance:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Retain
    UpdateReplacePolicy: Snapshot
```

### 2. ドリフト検出

定期的にドリフト検出を実行して、手動変更を検出:

```bash
aws cloudformation detect-stack-drift \
  --stack-name <STACK_NAME> \
  --region ap-northeast-1
```

### 3. バージョン管理

- すべてのテンプレートはGitで管理
- タグを使ってバージョン管理
- 変更時は必ずプルリクエストでレビュー

## トラブルシューティング

### スタック作成失敗時

1. CloudFormationイベントを確認:
```bash
aws cloudformation describe-stack-events \
  --stack-name <STACK_NAME> \
  --region ap-northeast-1
```

2. 自動ロールバックを確認
3. エラーメッセージに基づき修正
4. 再度デプロイ

### スタック更新失敗時

1. Change Setをキャンセル:
```bash
aws cloudformation cancel-update-stack \
  --stack-name <STACK_NAME> \
  --region ap-northeast-1
```

2. 前のバージョンに戻す:
```bash
aws cloudformation update-stack \
  --stack-name <STACK_NAME> \
  --template-body file://previous-version.yaml \
  --region ap-northeast-1
```

## 参照

- [CloudFormation設計書](../../docs/02_design/detailed/10_cloudformation/cloudformation_design.md)
- [スタック依存関係](../../docs/02_design/detailed/10_cloudformation/stack_dependencies.md)
- [AWS CloudFormation ベストプラクティス](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/best-practices.html)

## サポート

問題が発生した場合は、プロジェクト管理者に連絡してください。

---

**作成日**: 2025-11-05
**バージョン**: 1.0
**管理者**: admin@niigata-city.jp
