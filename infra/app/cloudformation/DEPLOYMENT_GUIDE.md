# CloudFormation デプロイ手順書

**対象システム**: 新潟市介護保険事業所システム
**最終更新日**: 2025-11-11
**作成者**: SRE エージェント

---

## 目次

1. [前提条件](#1-前提条件)
2. [デプロイ順序](#2-デプロイ順序)
3. [スタック別デプロイ手順](#3-スタック別デプロイ手順)
4. [ロールバック手順](#4-ロールバック手順)
5. [トラブルシューティング](#5-トラブルシューティング)

---

## 1. 前提条件

### 1.1 必要なツール

- AWS CLI v2 以降
- jq（JSON パース用）
- Git

### 1.2 AWS CLI 設定

```bash
# AWS プロファイル設定
aws configure --profile niigata-kaigo-dev

# 接続確認
aws sts get-caller-identity --profile niigata-kaigo-dev
```

### 1.3 IAM 権限

デプロイには以下の権限が必要です:

- CloudFormation: Full Access
- EC2, VPC, RDS, ElastiCache, ECS, ALB: Full Access
- S3: Read/Write（テンプレート保存用）
- IAM: PassRole, CreateRole, AttachRolePolicy
- Secrets Manager: CreateSecret, GetSecretValue

---

## 2. デプロイ順序

CloudFormation スタックは **依存関係に従って順番にデプロイ** する必要があります。

```
01. Common Network Stack (Transit Gateway)
     ↓
02. App Network Stack (VPC, Subnets, Route Tables)
     ↓
03. Security Stack (KMS, Security Groups)
     ↓
04. Database Stack (RDS, ElastiCache)
     ↓
05. Compute Stack (ALB, ECS)
     ↓
06. Storage Stack (S3, CloudFront)
     ↓
07. Auth Stack (Cognito)
     ↓
08. Monitoring Stack (CloudWatch, Backup)
```

**重要**: スタックを削除する場合は **逆順** で削除してください。

---

## 3. スタック別デプロイ手順

### 3.1 テンプレートを S3 にアップロード

```bash
# dev 環境用
aws s3 sync infra/app/cloudformation/templates/ \
  s3://niigata-kaigo-cfn-templates-dev/app/templates/ \
  --profile niigata-kaigo-dev

# staging 環境用
aws s3 sync infra/app/cloudformation/templates/ \
  s3://niigata-kaigo-cfn-templates-staging/app/templates/ \
  --profile niigata-kaigo-staging

# production 環境用
aws s3 sync infra/app/cloudformation/templates/ \
  s3://niigata-kaigo-cfn-templates-production/app/templates/ \
  --profile niigata-kaigo-production
```

---

### 3.2 Network Stack のデプロイ

#### 03-network Stack

**説明**: VPC、サブネット、ルートテーブル、NAT Gateway を作成します。

**デプロイ頻度**: 年1回程度（初回のみ、慎重に変更）

```bash
cd infra/app/cloudformation

# Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/03-network/main.yaml \
  --parameters file://parameters/dev/03-network-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# Change Set 詳細表示（dry-run）
CHANGE_SET_NAME=$(aws cloudformation list-change-sets \
  --stack-name niigata-kaigo-dev-03-network \
  --query 'Summaries[0].ChangeSetName' \
  --output text \
  --profile niigata-kaigo-dev)

aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# デプロイ完了を待機
aws cloudformation wait stack-create-complete \
  --stack-name niigata-kaigo-dev-03-network \
  --profile niigata-kaigo-dev

# スタック情報確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-03-network \
  --profile niigata-kaigo-dev
```

---

### 3.3 Security Stack のデプロイ

#### 04-security Stack

**説明**: KMS キー、Security Groups を作成します。

**デプロイ頻度**: 月1回程度

```bash
# Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-04-security \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/04-security/main.yaml \
  --parameters file://parameters/dev/04-security-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# Change Set 詳細表示
CHANGE_SET_NAME=$(aws cloudformation list-change-sets \
  --stack-name niigata-kaigo-dev-04-security \
  --query 'Summaries[0].ChangeSetName' \
  --output text \
  --profile niigata-kaigo-dev)

aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-dev-04-security \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-dev-04-security \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# デプロイ完了を待機
aws cloudformation wait stack-create-complete \
  --stack-name niigata-kaigo-dev-04-security \
  --profile niigata-kaigo-dev
```

---

### 3.4 Database Stack のデプロイ

#### 05-database Stack

**説明**: RDS MySQL、ElastiCache Redis を作成します。

**デプロイ頻度**: 月1回程度

**重要**: このスタックには以下の修正が含まれています:
- ✅ ElastiCache AuthToken が Secrets Manager から取得される
- ✅ CloudWatch Logs が90日保管される

```bash
# パラメータファイルの確認
cat parameters/dev/05-database-stack-params.json

# Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-05-database \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/05-database/main.yaml \
  --parameters file://parameters/dev/05-database-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# Change Set 詳細表示（dry-run）
CHANGE_SET_NAME=$(aws cloudformation list-change-sets \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Summaries[0].ChangeSetName' \
  --output text \
  --profile niigata-kaigo-dev)

aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-dev-05-database \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Changes[].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}' \
  --output table \
  --profile niigata-kaigo-dev

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-dev-05-database \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# デプロイ完了を待機（RDS/ElastiCache は時間がかかる: 15-20分）
aws cloudformation wait stack-create-complete \
  --stack-name niigata-kaigo-dev-05-database \
  --profile niigata-kaigo-dev

# スタック情報確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Stacks[0].Outputs' \
  --profile niigata-kaigo-dev
```

**デプロイ後の確認**:
```bash
# RDS エンドポイント確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Stacks[0].Outputs[?OutputKey==`DBInstanceEndpoint`].OutputValue' \
  --output text \
  --profile niigata-kaigo-dev

# Redis エンドポイント確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Stacks[0].Outputs[?OutputKey==`RedisPrimaryEndpoint`].OutputValue' \
  --output text \
  --profile niigata-kaigo-dev

# Secrets Manager の確認（RDS パスワード）
aws secretsmanager get-secret-value \
  --secret-id niigata-kaigo-dev-rds-master-password \
  --query 'SecretString' \
  --output text \
  --profile niigata-kaigo-dev

# Secrets Manager の確認（Redis AuthToken）
aws secretsmanager get-secret-value \
  --secret-id niigata-kaigo-dev-redis-auth-token \
  --query 'SecretString' \
  --output text \
  --profile niigata-kaigo-dev
```

---

### 3.5 Compute Stack のデプロイ

#### 06-compute Stack

**説明**: ALB、ECS Cluster、ECS Service を作成します。

**デプロイ頻度**: 週数回（Task Definition 変更時）

**重要**: このスタックには以下の修正が含まれています:
- ✅ ALB Access Logs が S3 に保存される（LogsBucketName 指定時）
- ✅ ECS Secrets が条件付きで設定される
- ✅ CloudWatch Logs が90日保管される

**事前準備**:
1. ALB Access Logs 用の S3 バケットを作成（オプション）
2. Docker イメージを ECR にプッシュ

```bash
# パラメータファイルの編集（必要に応じて）
vi parameters/dev/06-compute-stack-params.json

# 以下のパラメータを実際の値に置き換え:
# - VpcId
# - PublicSubnetIds
# - PrivateSubnetIds
# - ALBSecurityGroupId
# - ECSSecurityGroupId
# - BackendImageUri (ECR URI)
# - FrontendImageUri (ECR URI)
# - DBSecretArn (Database Stack の Outputs から取得)
# - RedisSecretArn (Database Stack の Outputs から取得)
# - LogsBucketName (オプション: ALB Access Logs 用)

# Database Stack の Outputs を取得
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Stacks[0].Outputs' \
  --profile niigata-kaigo-dev

# Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-06-compute \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/06-compute/main.yaml \
  --parameters file://parameters/dev/06-compute-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# Change Set 詳細表示
CHANGE_SET_NAME=$(aws cloudformation list-change-sets \
  --stack-name niigata-kaigo-dev-06-compute \
  --query 'Summaries[0].ChangeSetName' \
  --output text \
  --profile niigata-kaigo-dev)

aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-dev-06-compute \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Changes[].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}' \
  --output table \
  --profile niigata-kaigo-dev

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-dev-06-compute \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev

# デプロイ完了を待機（10-15分）
aws cloudformation wait stack-create-complete \
  --stack-name niigata-kaigo-dev-06-compute \
  --profile niigata-kaigo-dev
```

**デプロイ後の確認**:
```bash
# ALB DNS 名確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-06-compute \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNSName`].OutputValue' \
  --output text \
  --profile niigata-kaigo-dev

# ECS Service 状態確認
aws ecs describe-services \
  --cluster niigata-kaigo-dev-cluster \
  --services niigata-kaigo-dev-backend-service niigata-kaigo-dev-frontend-service \
  --profile niigata-kaigo-dev

# ECS Task 状態確認
aws ecs list-tasks \
  --cluster niigata-kaigo-dev-cluster \
  --service-name niigata-kaigo-dev-backend-service \
  --profile niigata-kaigo-dev

# CloudWatch Logs 確認
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/niigata-kaigo-dev \
  --profile niigata-kaigo-dev

# ログ保持期間確認（90日になっているか）
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/niigata-kaigo-dev \
  --query 'logGroups[].{Name:logGroupName,RetentionDays:retentionInDays}' \
  --output table \
  --profile niigata-kaigo-dev
```

---

### 3.6 Storage Stack のデプロイ

#### 07-storage Stack

**説明**: S3 バケット、CloudFront Distribution を作成します。

```bash
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-07-storage \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/07-storage/main.yaml \
  --parameters file://parameters/dev/07-storage-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# （以下、他のスタックと同様）
```

---

### 3.7 Auth Stack のデプロイ

#### 08-auth Stack

**説明**: Cognito User Pool、Identity Pool を作成します。

```bash
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-08-auth \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/08-auth/main.yaml \
  --parameters file://parameters/dev/08-auth-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# （以下、他のスタックと同様）
```

---

### 3.8 Monitoring Stack のデプロイ

#### 09-monitoring Stack

**説明**: CloudWatch Alarms、AWS Backup を作成します。

**重要**: このスタックには以下の修正が含まれています:
- ✅ SNS Topic の Condition が修正されている

```bash
# パラメータファイルの編集（必要に応じて）
vi parameters/dev/09-monitoring-stack-params.json

# 以下のパラメータを実際の値に置き換え:
# - LoadBalancerFullName (Compute Stack の ALB から取得)
# - ECSClusterName
# - ECSServiceName
# - DBInstanceId (Database Stack から取得)
# - ReplicationGroupId (Database Stack から取得)

aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-09-monitoring \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/09-monitoring/main.yaml \
  --parameters file://parameters/dev/09-monitoring-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# （以下、他のスタックと同様）
```

**デプロイ後の確認**:
```bash
# CloudWatch Alarms 一覧確認
aws cloudwatch describe-alarms \
  --alarm-name-prefix niigata-kaigo-dev \
  --profile niigata-kaigo-dev

# SNS Topic 確認
aws sns list-topics \
  --profile niigata-kaigo-dev | grep niigata-kaigo-dev
```

---

## 4. ロールバック手順

### 4.1 スタック単位のロールバック

```bash
# スタックをロールバック
aws cloudformation rollback-stack \
  --stack-name niigata-kaigo-dev-06-compute \
  --profile niigata-kaigo-dev

# ロールバック完了を待機
aws cloudformation wait stack-rollback-complete \
  --stack-name niigata-kaigo-dev-06-compute \
  --profile niigata-kaigo-dev
```

### 4.2 Change Set の削除（実行前）

```bash
# Change Set を実行せずに削除
aws cloudformation delete-change-set \
  --stack-name niigata-kaigo-dev-06-compute \
  --change-set-name $CHANGE_SET_NAME \
  --profile niigata-kaigo-dev
```

### 4.3 スタックの完全削除

**注意**: スタックを削除すると、すべてのリソースが削除されます。

```bash
# スタック削除（逆順で削除）
aws cloudformation delete-stack \
  --stack-name niigata-kaigo-dev-09-monitoring \
  --profile niigata-kaigo-dev

aws cloudformation wait stack-delete-complete \
  --stack-name niigata-kaigo-dev-09-monitoring \
  --profile niigata-kaigo-dev

# 以下、逆順で続ける
```

---

## 5. トラブルシューティング

### 5.1 Change Set 作成失敗

**エラー**: "No updates are to be performed"

**原因**: テンプレートに変更がない

**対処法**: Change Set を削除し、既存のスタックを使用する

---

### 5.2 スタック作成失敗（ROLLBACK_COMPLETE）

**エラー**: スタックが ROLLBACK_COMPLETE 状態

**原因**: リソース作成時にエラーが発生

**対処法**:
1. CloudFormation イベントを確認してエラー原因を特定
2. スタックを削除
3. パラメータを修正して再デプロイ

```bash
# エラー原因を確認
aws cloudformation describe-stack-events \
  --stack-name niigata-kaigo-dev-06-compute \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --profile niigata-kaigo-dev

# スタック削除
aws cloudformation delete-stack \
  --stack-name niigata-kaigo-dev-06-compute \
  --profile niigata-kaigo-dev
```

---

### 5.3 ECS タスクが起動しない

**症状**: ECS Service の Desired Count が Running Count より大きい

**原因**:
- Docker イメージが見つからない
- Secrets Manager の値が取得できない
- Security Group でアウトバウンド通信がブロックされている

**対処法**:
```bash
# ECS タスク失敗理由を確認
aws ecs describe-tasks \
  --cluster niigata-kaigo-dev-cluster \
  --tasks $(aws ecs list-tasks --cluster niigata-kaigo-dev-cluster --service-name niigata-kaigo-dev-backend-service --query 'taskArns[0]' --output text) \
  --profile niigata-kaigo-dev

# CloudWatch Logs を確認
aws logs tail /ecs/niigata-kaigo-dev-backend \
  --follow \
  --profile niigata-kaigo-dev
```

---

### 5.4 ALB でヘルスチェック失敗

**症状**: Target Group の Healthy Host Count が 0

**原因**:
- アプリケーションが起動していない
- ヘルスチェックパスが間違っている
- Security Group で ALB → ECS の通信がブロックされている

**対処法**:
```bash
# Target Group の状態確認
aws elbv2 describe-target-health \
  --target-group-arn $(aws cloudformation describe-stacks --stack-name niigata-kaigo-dev-06-compute --query 'Stacks[0].Outputs[?OutputKey==`BackendTargetGroupArn`].OutputValue' --output text) \
  --profile niigata-kaigo-dev
```

---

### 5.5 Redis 接続エラー

**症状**: アプリケーションから Redis に接続できない

**原因**:
- AuthToken が間違っている
- Security Group で ECS → ElastiCache の通信がブロックされている

**対処法**:
```bash
# Redis エンドポイント確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-05-database \
  --query 'Stacks[0].Outputs[?OutputKey==`RedisPrimaryEndpoint`].OutputValue' \
  --output text \
  --profile niigata-kaigo-dev

# AuthToken 確認
aws secretsmanager get-secret-value \
  --secret-id niigata-kaigo-dev-redis-auth-token \
  --query 'SecretString' \
  --output text \
  --profile niigata-kaigo-dev

# Security Group 確認
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*elasticache*" \
  --profile niigata-kaigo-dev
```

---

## 6. 定期メンテナンス

### 6.1 週次タスク

- [ ] ECS Task Definition の更新（アプリケーションデプロイ）
- [ ] CloudWatch Logs の確認（エラーログチェック）
- [ ] CloudWatch Alarms の確認（アラート発生履歴）

### 6.2 月次タスク

- [ ] RDS のメンテナンスウィンドウ確認
- [ ] ElastiCache のメンテナンスウィンドウ確認
- [ ] ALB Access Logs の確認（S3 容量チェック）
- [ ] CloudWatch Logs の保持期間確認（90日設定されているか）

### 6.3 年次タスク

- [ ] VPC CIDR の拡張検討
- [ ] Security Group の棚卸し
- [ ] IAM ロールの棚卸し

---

**作成者**: SRE エージェント
**承認者**: PM エージェント（承認待ち）
