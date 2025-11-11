# 監視スタック デプロイガイド

## 概要

本ガイドでは、新潟市介護保険事業所システムの監視スタックをデプロイする手順を説明します。

監視スタックは以下の2つのアカウントで構成されます：

- **Common Account**: セキュリティ監視（CloudTrail, Config, GuardDuty, Security Hub）
- **App Account**: アプリケーション監視（SNS Topics, CloudWatch Logs, Alarms, Backup）

## デプロイ前提条件

### Common Account

- [ ] AWS認証情報が設定されている（Common Account）
- [ ] S3バケット作成権限がある
- [ ] CloudFormation実行権限がある
- [ ] Organizations管理者権限がある（CloudTrail Organization Trail用）

### App Account

- [ ] AWS認証情報が設定されている（App Account）
- [ ] S3バケット作成権限がある
- [ ] CloudFormation実行権限がある
- [ ] **VPCスタックがデプロイ済み**（VPC IDが必要）

## 環境別設定

### dev環境

| パラメータ | 値 |
|-----------|-----|
| AlertEmailAddress | `infra-alerts-dev@example.com` |
| LogRetentionDays | 90日 |
| FlowLogsRetentionDays | 90日 |
| BackupDeleteAfterDays | 7日 |

### staging環境

| パラメータ | 値 |
|-----------|-----|
| AlertEmailAddress | `infra-alerts-staging@example.com` |
| LogRetentionDays | 90日 |
| FlowLogsRetentionDays | 90日 |
| BackupDeleteAfterDays | 30日 |

### production環境

| パラメータ | 値 |
|-----------|-----|
| AlertEmailAddress | `infra-alerts-production@example.com` |
| LogRetentionDays | 365日（GCAS要件） |
| FlowLogsRetentionDays | 365日（GCAS要件） |
| BackupDeleteAfterDays | 90日 |

## デプロイ手順

### 1. Common Account セキュリティ監視スタック

#### 1.1 テンプレートアップロード

```bash
# production環境の場合
./scripts/upload-templates.sh production

# staging環境の場合
./scripts/upload-templates.sh staging
```

**確認**:
```bash
# アップロードされたテンプレートを確認
aws s3 ls s3://niigata-kaigo-cfn-templates-production/common/templates/ --recursive
```

#### 1.2 セキュリティ監視スタックデプロイ

```bash
# production環境の場合
./scripts/deploy-common-security-monitoring.sh production

# staging環境の場合
./scripts/deploy-common-security-monitoring.sh staging
```

**デプロイ内容**:
- Security Log Buckets（CloudTrail, Config, VPC Flow Logs, ALB Logs）
- Security SNS Topics（Critical, Warning, Info）
- CloudTrail（Organization Trail）
- AWS Config（Compliance Monitoring）
- GuardDuty + Security Hub（Threat Detection）

**所要時間**: 約5-10分

**デプロイ結果の確認**:
```bash
# スタック状態確認
aws cloudformation describe-stacks --stack-name niigata-kaigo-production-common-security-monitoring

# CloudTrail有効化確認
aws cloudtrail describe-trails

# AWS Config有効化確認
aws configservice describe-configuration-recorders

# GuardDuty有効化確認
aws guardduty list-detectors

# Security Hub有効化確認
aws securityhub describe-hub
```

---

### 2. App Account アプリケーション監視スタック

#### 2.1 VPCスタックのデプロイ（事前準備）

監視スタックをデプロイする前に、**VPCスタックが必要**です。

```bash
# dev環境の場合
./scripts/deploy-multi-account.sh dev app 02-network
```

**VPC ID取得**:
```bash
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-app-network \
  --query 'Stacks[0].Outputs[?OutputKey==`AppVPCId`].OutputValue' \
  --output text)

echo "VPC ID: $VPC_ID"
```

#### 2.2 テンプレートアップロード

```bash
# dev環境の場合
./scripts/upload-templates.sh dev

# staging環境の場合
./scripts/upload-templates.sh staging

# production環境の場合
./scripts/upload-templates.sh production
```

**確認**:
```bash
# アップロードされたテンプレートを確認
aws s3 ls s3://niigata-kaigo-cfn-templates-dev/app/templates/monitoring/ --recursive
```

#### 2.3 監視スタックデプロイ

```bash
# dev環境の場合（VPC IDを自動取得）
./scripts/deploy-app-monitoring.sh dev

# または、VPC IDを明示的に指定
./scripts/deploy-app-monitoring.sh dev --vpc-id vpc-0123456789abcdef0

# staging環境の場合
./scripts/deploy-app-monitoring.sh staging

# production環境の場合
./scripts/deploy-app-monitoring.sh production
```

**デプロイ内容**:
- App SNS Topics（Critical, Warning, Info）
- App CloudWatch Log Groups（ECS, RDS, ALB）
- VPC Flow Logs（GCAS Requirement）
- CloudWatch Alarms（ALB, ECS, RDS, ElastiCache）
- AWS Backup Plan（RDS, EBS）

**所要時間**: 約5-10分

**デプロイ結果の確認**:
```bash
# スタック状態確認
aws cloudformation describe-stacks --stack-name niigata-kaigo-dev-app-monitoring

# SNS Topics確認
aws sns list-topics

# CloudWatch Log Groups確認
aws logs describe-log-groups --log-group-name-prefix /aws/ecs/niigata-kaigo-dev

# VPC Flow Logs確認
aws logs tail /aws/vpc/flowlogs/niigata-kaigo-dev-app-vpc --follow

# CloudWatch Alarms確認
aws cloudwatch describe-alarms

# AWS Backup Plan確認
aws backup list-backup-plans
```

---

### 3. SNSサブスクリプション確認

デプロイ後、**SNSサブスクリプション確認メール**が送信されます。

**手順**:
1. メールボックスを確認
2. AWS SNS からの「AWS Notification - Subscription Confirmation」メールを開く
3. 「Confirm subscription」リンクをクリック
4. ブラウザで確認ページが開く

**確認が必要なトピック**:
- Critical Alerts（緊急アラート）
- Warning Alerts（警告アラート）
- Info Alerts（情報アラート）

**サブスクリプション確認状態の確認**:
```bash
# Common Account
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-1:ACCOUNT_ID:niigata-kaigo-production-critical-alerts

# App Account
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-1:ACCOUNT_ID:niigata-kaigo-dev-critical-alerts
```

---

## デプロイ順序（全環境）

### production環境

```bash
# 1. Common Account: テンプレートアップロード
./scripts/upload-templates.sh production

# 2. Common Account: セキュリティ監視スタックデプロイ
./scripts/deploy-common-security-monitoring.sh production

# 3. App Account: テンプレートアップロード
./scripts/upload-templates.sh production

# 4. App Account: VPCスタックデプロイ（事前準備）
./scripts/deploy-multi-account.sh production app 02-network

# 5. App Account: 監視スタックデプロイ
./scripts/deploy-app-monitoring.sh production

# 6. SNSサブスクリプション確認メールを承認
```

### staging環境

```bash
# 1. Common Account: テンプレートアップロード
./scripts/upload-templates.sh staging

# 2. Common Account: セキュリティ監視スタックデプロイ
./scripts/deploy-common-security-monitoring.sh staging

# 3. App Account: テンプレートアップロード
./scripts/upload-templates.sh staging

# 4. App Account: VPCスタックデプロイ（事前準備）
./scripts/deploy-multi-account.sh staging app 02-network

# 5. App Account: 監視スタックデプロイ
./scripts/deploy-app-monitoring.sh staging

# 6. SNSサブスクリプション確認メールを承認
```

### dev環境

```bash
# 1. App Account: テンプレートアップロード
./scripts/upload-templates.sh dev

# 2. App Account: VPCスタックデプロイ（事前準備）
./scripts/deploy-multi-account.sh dev app 02-network

# 3. App Account: 監視スタックデプロイ
./scripts/deploy-app-monitoring.sh dev

# 4. SNSサブスクリプション確認メールを承認
```

---

## トラブルシューティング

### エラー: VPC IDが見つからない

**原因**: VPCスタックがデプロイされていない

**対処法**:
```bash
# VPCスタックをデプロイ
./scripts/deploy-multi-account.sh dev app 02-network

# VPC IDを確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-dev-app-network \
  --query 'Stacks[0].Outputs[?OutputKey==`AppVPCId`].OutputValue' \
  --output text
```

### エラー: S3バケットが存在しない

**原因**: テンプレートがアップロードされていない

**対処法**:
```bash
# テンプレートをアップロード
./scripts/upload-templates.sh dev

# バケット確認
aws s3 ls s3://niigata-kaigo-cfn-templates-dev/
```

### エラー: Change Set作成に失敗

**原因**: パラメータファイルの値が不正

**対処法**:
```bash
# パラメータファイルを確認
cat infra/app/cloudformation/parameters/dev/09-monitoring-stack-params.json

# 必須パラメータ:
# - AlertEmailAddress（メールアドレス形式）
# - VPCId（vpc-で始まる有効なID）
# - KMSKeyId（Securityスタックで作成済み）
```

### エラー: KMS Keyが見つからない

**原因**: Securityスタックがデプロイされていない

**対処法**:
```bash
# Securityスタックをデプロイ
./scripts/deploy-multi-account.sh dev app 03-security

# KMS Key IDを確認
aws kms list-keys --region ap-northeast-1
```

---

## ロールバック手順

デプロイに失敗した場合や、前のバージョンに戻したい場合：

```bash
# スタックを削除
aws cloudformation delete-stack --stack-name niigata-kaigo-dev-app-monitoring

# 削除完了を待つ
aws cloudformation wait stack-delete-complete --stack-name niigata-kaigo-dev-app-monitoring
```

---

## 参考資料

- [CloudFormation 構成設計](../02_設計/基本設計/10_インフラ/10_CloudFormation構成/)
- [監視設計](../02_設計/基本設計/10_インフラ/08_監視・ロギング設計/)
- [セキュリティ設計](../02_設計/基本設計/10_インフラ/03_セキュリティ設計/)

---

**作成日**: 2025-11-11
**更新日**: 2025-11-11
**作成者**: SRE Agent
