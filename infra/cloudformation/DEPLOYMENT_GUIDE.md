# CloudFormation デプロイガイド

新潟市介護保険事業所システムのインフラストラクチャデプロイメント手順書

---

## 📋 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [Phase別デプロイ構成](#phase別デプロイ構成)
4. [デプロイ方法](#デプロイ方法)
5. [スクリプト一覧](#スクリプト一覧)
6. [トラブルシューティング](#トラブルシューティング)
7. [ロールバック手順](#ロールバック手順)

---

## 概要

### デプロイ方針

- **Change Sets必須**: すべてのデプロイでChange Setsによるdry-runを実施
- **Phase別デプロイ**: 依存関係を考慮した段階的デプロイ
- **環境分離**: staging / production 環境の完全分離
- **OIDC認証**: GitHub ActionsからAWSへの安全なアクセス

### CloudFormationスタック構成

全25スタック（staging/production 各環境）

- **Phase 1**: 監査・ネットワーク基盤（6スタック）
- **Phase 2**: セキュリティ（2スタック）
- **Phase 3**: データ層（1スタック）
- **Phase 4**: コンピューティング（2スタック）
- **Phase 5**: ストレージ・認証（5スタック）

---

## 前提条件

### 必要な環境

- AWS CLI（v2.x以降）インストール済み
- AWS認証情報設定済み（OIDC または IAMユーザー）
- Bash環境（Linux / macOS / WSL）
- cfn-lint インストール済み（オプション）

### AWS権限

必要なIAM権限:
- CloudFormation（全操作）
- 各AWSサービス（VPC, EC2, RDS, ECS, Cognito, S3, KMS等）
- CloudTrail, AWS Config（監査ログ）

### GitHub Actions設定

- **GitHub Secrets**:
  - `AWS_ROLE_ARN`: OIDC認証用IAMロールARN
- **Environment Protection Rules**:
  - `staging-infra`: 自動デプロイ可
  - `production-infra`: 手動承認必須

---

## Phase別デプロイ構成

### Phase 1: 監査・ネットワーク基盤

**目的**: すべてのインフラの基盤となる監査ログとネットワークを構築

| スタック | 説明 | 依存関係 |
|---------|------|---------|
| `cloudtrail-stack` | 監査ログ（CloudTrail） | なし |
| `aws-config-stack` | コンプライアンス（AWS Config） | なし |
| `vpc-core-stack` | VPC + Internet Gateway | なし |
| `subnets-stack` | Public/Private Subnets | VPC |
| `nat-gateways-stack` | NAT Gateways | Subnets |
| `route-tables-stack` | Route Tables | NAT GW |

**デプロイ時間**: 約15分

### Phase 2: セキュリティ

**目的**: 暗号化とネットワークセキュリティの構築

| スタック | 説明 | 依存関係 |
|---------|------|---------|
| `kms-stack` | 暗号化キー（KMS） | なし |
| `security-groups-stack` | Security Groups（ALB, ECS, RDS） | VPC |

**デプロイ時間**: 約5分

### Phase 3: データ層

**目的**: データベースの構築

| スタック | 説明 | 依存関係 |
|---------|------|---------|
| `rds-stack` | RDS MySQL（Multi-AZ） | VPC, Subnets, Security Groups |

**デプロイ時間**: 約20分（Multi-AZ構成のため）

### Phase 4: コンピューティング

**目的**: アプリケーション実行基盤の構築

| スタック | 説明 | 依存関係 |
|---------|------|---------|
| `alb-stack` | Application Load Balancer | VPC, Subnets, Security Groups |
| `ecs-stack` | ECS Fargate Cluster + Services | VPC, ALB, Security Groups |

**デプロイ時間**: 約10分

### Phase 5: ストレージ・認証

**目的**: フロントエンドホスティングとユーザー認証の構築

| スタック | 説明 | 依存関係 |
|---------|------|---------|
| `s3-stack` | S3 Bucket（Frontend hosting） | KMS |
| `cognito-user-pool` | Cognito User Pool | なし |
| `cognito-identity-pool` | Cognito Identity Pool | User Pool |
| `cognito-dynamodb-tables` | DynamoDB（Cognitoデータ） | なし |
| `cognito-lambda-triggers` | Lambda Triggers（Cognito） | User Pool |

**デプロイ時間**: 約10分

---

## デプロイ方法

### 1. ローカル環境でのデプロイ

#### Phase単位でのデプロイ（推奨）

```bash
# Phase 1をステージング環境にデプロイ
cd infra/cloudformation/scripts
./deploy-phase.sh staging phase1

# Phase 2をステージング環境にデプロイ
./deploy-phase.sh staging phase2

# Phase 3をステージング環境にデプロイ
./deploy-phase.sh staging phase3

# Phase 4をステージング環境にデプロイ
./deploy-phase.sh staging phase4

# Phase 5をステージング環境にデプロイ
./deploy-phase.sh staging phase5
```

#### 全Phaseを一括デプロイ

```bash
# ステージング環境に全Phase一括デプロイ
for phase in phase1 phase2 phase3 phase4 phase5; do
  ./deploy-phase.sh staging $phase
done
```

#### 個別スタックのデプロイ

```bash
# 個別スタックをデプロイ（詳細な制御が必要な場合）
./deploy.sh staging 02_network vpc-core-stack
```

### 2. GitHub Actionsでの自動デプロイ

#### Staging環境（自動デプロイ）

```bash
# developブランチにマージすると自動デプロイ
git checkout develop
git pull origin develop
git merge feature/new-infrastructure
git push origin develop
```

**自動実行フロー**:
1. `validate` ジョブ: テンプレート検証
2. `deploy-staging-phase1`: Phase 1デプロイ
3. `deploy-staging-phase2`: Phase 2デプロイ（Phase 1完了後）
4. `deploy-staging-phase3`: Phase 3デプロイ（Phase 2完了後）
5. `deploy-staging-phase4`: Phase 4デプロイ（Phase 2完了後）
6. `deploy-staging-phase5`: Phase 5デプロイ（Phase 2完了後）

#### Production環境（手動トリガー）

```bash
# mainブランチへのマージ後、GitHub Actionsで手動実行
git checkout main
git pull origin main
git merge develop
git push origin main
```

**GitHub Actions手動実行**:
1. GitHubリポジトリの "Actions" タブを開く
2. "Infrastructure CI/CD" ワークフローを選択
3. "Run workflow" ボタンをクリック
4. 環境（`production`）とPhase（`phase1`〜`phase5` or `all`）を選択
5. "Run workflow" を実行
6. 承認者が承認後、デプロイ開始

---

## スクリプト一覧

### デプロイスクリプト

| スクリプト | 説明 | 使用例 |
|----------|------|--------|
| `deploy.sh` | 単一スタックのデプロイ | `./deploy.sh staging 02_network vpc-core-stack` |
| `deploy-phase.sh` | Phase単位のデプロイ | `./deploy-phase.sh staging phase1` |
| `describe-changeset.sh` | Change Set内容確認（dry-run） | `./describe-changeset.sh staging 02_network vpc-core-stack changeset-20251107` |
| `execute-changeset.sh` | Change Set実行 | `./execute-changeset.sh staging 02_network vpc-core-stack changeset-20251107` |
| `rollback.sh` | スタックロールバック | `./rollback.sh staging 02_network vpc-core-stack` |

### 検証スクリプト

| スクリプト | 説明 | 使用例 |
|----------|------|--------|
| `validate.sh` | テンプレート検証 | `./validate.sh production/02_network/vpc-core-stack.yaml` |

### 削除スクリプト

| スクリプト | 説明 | 使用例 |
|----------|------|--------|
| `delete-stack.sh` | 単一スタック削除 | `./delete-stack.sh staging 02_network vpc-core-stack` |
| `delete-all-stacks.sh` | 全スタック削除（開発用） | `./delete-all-stacks.sh staging` |

---

## トラブルシューティング

### 1. Change Set作成に失敗する

**エラー**: `No updates are to be performed`

**原因**: テンプレートに変更がない

**対処法**:
```bash
# 変更がない場合は正常（エラーではない）
# テンプレートを確認し、意図的な変更がない場合は問題なし
```

---

### 2. スタック更新が `UPDATE_ROLLBACK_COMPLETE` で止まる

**エラー**: スタックが `UPDATE_ROLLBACK_COMPLETE` 状態

**原因**: 更新に失敗し、自動ロールバックが完了した状態

**対処法**:
```bash
# スタックイベントを確認
aws cloudformation describe-stack-events \
  --stack-name niigata-kaigo-staging-vpc-core-stack \
  --region ap-northeast-1

# 失敗原因を特定してテンプレートを修正
# 再度Change Setを作成して実行
./deploy.sh staging 02_network vpc-core-stack
```

---

### 3. スタック削除が失敗する（`DELETE_FAILED`）

**エラー**: スタック削除が `DELETE_FAILED` 状態

**原因**: 依存関係があるリソースがまだ存在する

**対処法**:
```bash
# 依存スタックを先に削除
# 例: ECSスタックを削除してからALBスタックを削除

# または、リソース保持で削除
aws cloudformation delete-stack \
  --stack-name niigata-kaigo-staging-vpc-core-stack \
  --retain-resources VPC InternetGateway \
  --region ap-northeast-1
```

---

### 4. RDSデプロイが20分以上かかる

**症状**: RDSスタックのデプロイに時間がかかる

**原因**: Multi-AZ構成のため、正常な動作

**対処法**:
```bash
# 進捗を確認
aws cloudformation describe-stack-events \
  --stack-name niigata-kaigo-staging-rds-stack \
  --region ap-northeast-1 \
  --max-items 10

# 待機（通常15〜25分）
# エラーが発生していなければ正常
```

---

### 5. GitHub Actionsでデプロイが失敗する

**エラー**: `Error: Unable to assume role`

**原因**: OIDC認証の設定が誤っている

**対処法**:
1. IAMロールの信頼関係を確認
2. GitHub SecretsのARNを確認
3. GitHub ActionsワークフローのOIDC設定を確認

```json
// IAMロールの信頼関係（正しい例）
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::897167645238:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-org/niigatacity-kaigo-subsystem:*"
        }
      }
    }
  ]
}
```

---

## ロールバック手順

### 1. Change Set実行前（推奨）

**Change Setを作成したが、まだ実行していない場合**

```bash
# Change Set削除（変更を適用しない）
aws cloudformation delete-change-set \
  --stack-name niigata-kaigo-staging-vpc-core-stack \
  --change-set-name changeset-20251107120000 \
  --region ap-northeast-1

# 確認
echo "Change Setを削除しました。スタックは元の状態のままです。"
```

---

### 2. Change Set実行後（スタック更新失敗時）

**スタック更新が失敗し、自動ロールバックが発生した場合**

```bash
# ロールバックスクリプトを使用
./rollback.sh staging 02_network vpc-core-stack

# または、AWS CLIで直接ロールバック
aws cloudformation cancel-update-stack \
  --stack-name niigata-kaigo-staging-vpc-core-stack \
  --region ap-northeast-1

# ロールバック完了を待機
aws cloudformation wait stack-update-rollback-complete \
  --stack-name niigata-kaigo-staging-vpc-core-stack \
  --region ap-northeast-1
```

---

### 3. 前のバージョンに戻す

**デプロイ完了後に前のバージョンに戻したい場合**

```bash
# 前のテンプレートを使用してChange Setを作成
# 例: v1.2.0 から v1.1.0 に戻す

# Gitで前のバージョンをチェックアウト
git checkout tags/infra-v1.1.0

# 前のテンプレートでChange Set作成
./deploy.sh staging 02_network vpc-core-stack

# Change Set確認後、実行
# （deploy.shが自動的にChange Setを作成・確認・実行）
```

---

### 4. 本番環境でのロールバック（緊急時）

**本番環境で問題が発生し、緊急ロールバックが必要な場合**

```bash
# ⚠️ 本番環境での操作は慎重に

# 1. 問題の特定
aws cloudformation describe-stack-events \
  --stack-name niigata-kaigo-production-ecs-stack \
  --region ap-northeast-1 \
  --max-items 20

# 2. ロールバック実行（手動確認あり）
./rollback.sh production 04_compute ecs-stack

# 3. ロールバック完了確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-production-ecs-stack \
  --region ap-northeast-1 \
  --query 'Stacks[0].StackStatus' \
  --output text
```

---

## ベストプラクティス

### デプロイ前のチェックリスト

- [ ] テンプレートファイルの構文検証（`cfn-lint`）
- [ ] パラメータファイルの環境確認（staging / production）
- [ ] Change Setで変更内容を確認（dry-run）
- [ ] 依存スタックが正常に稼働している
- [ ] バックアップが取得されている（RDS, DynamoDB）
- [ ] ロールバック手順を確認済み

### デプロイ時の注意事項

1. **本番環境デプロイは営業時間外に実施**
   - 推奨時間: 深夜1時〜5時
   - メンテナンス通知を事前に実施

2. **Phase単位でデプロイ**
   - 全スタック一括デプロイは避ける
   - Phase 1完了後、Phase 2開始

3. **Change Set必須**
   - 直接デプロイ（`aws cloudformation deploy`）は禁止
   - 必ずChange Setで変更内容を確認

4. **監視を継続**
   - デプロイ中はCloudWatch Logsを監視
   - エラー発生時は即座にロールバック

---

## 参考資料

- [CloudFormation標準](.claude/docs/40_standards/45_cloudformation.md)
- [IaC戦略](../../docs/02_設計/基本設計/10_CICD/IaC戦略.md)
- [GitHub Actions設計](../../docs/02_設計/基本設計/10_CICD/GitHub_Actions設計.md)
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)

---

**作成日**: 2025-11-08
**作成者**: Claude (sre サブエージェント)
**レビュー状態**: Draft
