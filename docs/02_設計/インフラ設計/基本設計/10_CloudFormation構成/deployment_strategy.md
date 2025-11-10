# CloudFormation デプロイ戦略と Change Sets 運用

**作成日**: 2025-11-09
**更新日**: 2025-11-09
**対象環境**: 本番（Production）、ステージング（Staging）

---

## 1. 目的

このドキュメントでは、新潟市介護保険事業所システムにおける CloudFormation のデプロイ戦略と Change Sets を使った安全なデプロイ手順を定義します。

**背景**:
- 本番環境への誤操作防止
- 変更内容の事前確認（dry-run）
- ロールバック手順の明確化
- 安全性と再現性の確保

---

## 2. デプロイの基本方針

### 2.1 Change Sets 必須（dry-run）

**原則**: 本番環境に対して、直接デプロイ（`aws cloudformation deploy`）を**絶対にしない**。

**必須フロー**:

```
1. Change Set 作成（差分確認）
   ↓
2. Change Set 内容確認（dry-run）
   ↓
3. ユーザー承認
   ↓
4. Change Set 実行（本番デプロイ）
```

**理由**:
- 誤操作による本番環境の破壊を防ぐ
- 変更内容を事前にレビューできる
- ユーザーが変更内容を理解してから実行できる

### 2.2 デプロイスクリプトの構成

以下の4つのスクリプトを用意します:

| スクリプト | 役割 | 実行タイミング |
|-----------|------|--------------|
| `scripts/create-changeset.sh` | Change Set 作成 | デプロイ前（dry-run） |
| `scripts/describe-changeset.sh` | Change Set 内容確認 | デプロイ前（レビュー） |
| `scripts/execute-changeset.sh` | Change Set 実行 | ユーザー承認後 |
| `scripts/rollback.sh` | ロールバック | 問題発生時 |

---

## 3. デプロイスクリプト詳細

### 3.1 create-changeset.sh（Change Set 作成）

**目的**: CloudFormation Change Set を作成し、変更内容を確認できる状態にする。

**使い方**:

```bash
# 基本構文
./scripts/create-changeset.sh <stack-name> <template-file> <parameters-file> <environment>

# 例: Staging 環境の Network スタック
./scripts/create-changeset.sh \
  niigata-kaigo-staging-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# 例: Production 環境の Network スタック
./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

**スクリプト内部処理**:

```bash
#!/bin/bash
set -e

STACK_NAME=$1
TEMPLATE_FILE=$2
PARAMETERS_FILE=$3
ENVIRONMENT=$4
CHANGESET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

echo "Creating Change Set: ${CHANGESET_NAME}"
echo "Stack: ${STACK_NAME}"
echo "Template: ${TEMPLATE_FILE}"
echo "Parameters: ${PARAMETERS_FILE}"
echo "Environment: ${ENVIRONMENT}"

aws cloudformation create-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --template-body "file://${TEMPLATE_FILE}" \
  --parameters "file://${PARAMETERS_FILE}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --tags Key=Environment,Value="${ENVIRONMENT}" \
        Key=ManagedBy,Value=CloudFormation \
        Key=Project,Value=NiigataKaigoSystem

echo "Waiting for Change Set to be created..."
aws cloudformation wait change-set-create-complete \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}"

echo "✅ Change Set created successfully: ${CHANGESET_NAME}"
echo ""
echo "Next step: Review the Change Set"
echo "./scripts/describe-changeset.sh ${STACK_NAME} ${CHANGESET_NAME}"
```

### 3.2 describe-changeset.sh（Change Set 内容確認）

**目的**: Change Set の変更内容を詳細に表示し、レビューする。

**使い方**:

```bash
# 基本構文
./scripts/describe-changeset.sh <stack-name> <changeset-name>

# 例
./scripts/describe-changeset.sh \
  niigata-kaigo-staging-network-stack \
  niigata-kaigo-staging-network-stack-changeset-20251109-143000
```

**スクリプト内部処理**:

```bash
#!/bin/bash
set -e

STACK_NAME=$1
CHANGESET_NAME=$2

echo "========================================"
echo "Change Set Details"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Change Set: ${CHANGESET_NAME}"
echo ""

aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query '{
    Status: Status,
    StatusReason: StatusReason,
    Changes: Changes[*].{
      Action: ResourceChange.Action,
      LogicalResourceId: ResourceChange.LogicalResourceId,
      ResourceType: ResourceChange.ResourceType,
      Replacement: ResourceChange.Replacement,
      Scope: ResourceChange.Scope
    }
  }' \
  --output table

echo ""
echo "========================================"
echo "Review the changes above carefully!"
echo "========================================"
echo ""
echo "If the changes look good, execute the Change Set:"
echo "./scripts/execute-changeset.sh ${STACK_NAME} ${CHANGESET_NAME}"
echo ""
echo "If the changes are NOT correct, delete the Change Set:"
echo "aws cloudformation delete-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGESET_NAME}"
```

**出力例**:

```
========================================
Change Set Details
========================================
Stack: niigata-kaigo-staging-network-stack
Change Set: niigata-kaigo-staging-network-stack-changeset-20251109-143000

--------------------------------------------------------------------
|                       DescribeChangeSet                          |
+------------------------------------------------------------------+
||                           Changes                              ||
|+----------+---------------------+------------------+------------+|
|| Action   | LogicalResourceId   | ResourceType     | Replacement||
|+----------+---------------------+------------------+------------+|
|| Add      | ServiceVPC          | AWS::EC2::VPC    | N/A        ||
|| Add      | InternetGateway     | AWS::EC2::IGW    | N/A        ||
|| Add      | PublicSubnet1       | AWS::EC2::Subnet | N/A        ||
|| Add      | PublicSubnet2       | AWS::EC2::Subnet | N/A        ||
|+----------+---------------------+------------------+------------+|

========================================
Review the changes above carefully!
========================================
```

### 3.3 execute-changeset.sh（Change Set 実行）

**目的**: Change Set を実行し、実際に AWS リソースを作成・変更する。

**使い方**:

```bash
# 基本構文
./scripts/execute-changeset.sh <stack-name> <changeset-name>

# 例
./scripts/execute-changeset.sh \
  niigata-kaigo-staging-network-stack \
  niigata-kaigo-staging-network-stack-changeset-20251109-143000
```

**スクリプト内部処理**:

```bash
#!/bin/bash
set -e

STACK_NAME=$1
CHANGESET_NAME=$2

echo "========================================"
echo "Executing Change Set"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Change Set: ${CHANGESET_NAME}"
echo ""

read -p "Are you sure you want to execute this Change Set? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Change Set execution cancelled."
  exit 1
fi

echo "Executing Change Set..."
aws cloudformation execute-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}"

echo "Waiting for stack to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name "${STACK_NAME}" \
  || aws cloudformation wait stack-update-complete \
  --stack-name "${STACK_NAME}"

echo "✅ Stack deployment completed successfully!"
echo ""
echo "Check stack status:"
echo "aws cloudformation describe-stacks --stack-name ${STACK_NAME}"
```

### 3.4 rollback.sh（ロールバック）

**目的**: デプロイに問題があった場合、前のバージョンにロールバックする。

**使い方**:

```bash
# 基本構文
./scripts/rollback.sh <stack-name>

# 例
./scripts/rollback.sh niigata-kaigo-staging-network-stack
```

**スクリプト内部処理**:

```bash
#!/bin/bash
set -e

STACK_NAME=$1

echo "========================================"
echo "Rolling back stack"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo ""

read -p "Are you sure you want to rollback this stack? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Rollback cancelled."
  exit 1
fi

echo "Rolling back..."
aws cloudformation cancel-update-stack --stack-name "${STACK_NAME}"

echo "Waiting for rollback to complete..."
aws cloudformation wait stack-rollback-complete --stack-name "${STACK_NAME}"

echo "✅ Rollback completed successfully!"
echo ""
echo "Check stack status:"
echo "aws cloudformation describe-stacks --stack-name ${STACK_NAME}"
```

---

## 4. デプロイ手順（段階的デプロイ）

### 4.1 初回デプロイ（Staging 環境）

**順序**: ライフサイクルの長いスタックから順にデプロイ

```bash
# ステップ1: Audit スタック（CloudTrail, AWS Config, GuardDuty）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-audit-stack \
  infra/cloudformation/stacks/01-audit/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

./scripts/describe-changeset.sh \
  niigata-kaigo-staging-audit-stack \
  <changeset-name>

./scripts/execute-changeset.sh \
  niigata-kaigo-staging-audit-stack \
  <changeset-name>

# ステップ2: Network スタック（VPC, Subnets, NAT Gateway, Route Tables）
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

# ステップ3: Security スタック（WAF, Security Hub, KMS）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-security-stack \
  infra/cloudformation/stacks/03-security/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ4: Database スタック（RDS, ElastiCache）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-database-stack \
  infra/cloudformation/stacks/04-database/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ5: Storage スタック（S3, CloudFront）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-storage-stack \
  infra/cloudformation/stacks/05-storage/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ6: Compute Base スタック（ECS Cluster, ALB, ECR）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-compute-base-stack \
  infra/cloudformation/stacks/06-compute-base/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ7: Compute App スタック（ECS Task Definition, Service）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-compute-app-stack \
  infra/cloudformation/stacks/07-compute-app/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ8: Monitoring スタック（CloudWatch, SNS）
./scripts/create-changeset.sh \
  niigata-kaigo-staging-monitoring-stack \
  infra/cloudformation/stacks/08-monitoring/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging
```

### 4.2 Production 環境へのデプロイ

**前提条件**: Staging 環境でのデプロイが正常に完了していること

**手順**:

```bash
# Production 環境も同じ順序でデプロイ
# parameters/production.json を使用

./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production

# ... 以降、同様に Staging と同じ順序でデプロイ
```

---

## 5. GitHub Actions によるCI/CD

### 5.1 ワークフロー構成

```yaml
# .github/workflows/infra-deploy.yml
name: Infrastructure Deployment

on:
  push:
    branches:
      - master
    paths:
      - 'infra/cloudformation/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/master' || github.event.inputs.environment == 'staging'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_STAGING }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_STAGING }}
          aws-region: ap-northeast-1

      - name: Create Change Set (Network)
        run: |
          ./scripts/create-changeset.sh \
            niigata-kaigo-staging-network-stack \
            infra/cloudformation/stacks/02-network/main.yaml \
            infra/cloudformation/parameters/staging.json \
            staging

      - name: Describe Change Set (Network)
        run: |
          CHANGESET_NAME=$(aws cloudformation list-change-sets \
            --stack-name niigata-kaigo-staging-network-stack \
            --query 'Summaries[0].ChangeSetName' \
            --output text)

          ./scripts/describe-changeset.sh \
            niigata-kaigo-staging-network-stack \
            $CHANGESET_NAME

      - name: Execute Change Set (Network) - Manual Approval Required
        if: github.event_name == 'workflow_dispatch'
        run: |
          CHANGESET_NAME=$(aws cloudformation list-change-sets \
            --stack-name niigata-kaigo-staging-network-stack \
            --query 'Summaries[0].ChangeSetName' \
            --output text)

          echo "yes" | ./scripts/execute-changeset.sh \
            niigata-kaigo-staging-network-stack \
            $CHANGESET_NAME

  deploy-production:
    if: github.event.inputs.environment == 'production'
    runs-on: ubuntu-latest
    environment: production
    needs: deploy-staging
    steps:
      # ... Production deployment steps (similar to staging)
```

### 5.2 手動承認プロセス

**GitHub Environments を使用**:

1. GitHub リポジトリ → Settings → Environments
2. `production` 環境を作成
3. "Required reviewers" を設定（例: プロジェクトマネージャー、SRE）
4. Production デプロイ前に承認が必要になる

---

## 6. エラーハンドリングとロールバック

### 6.1 よくあるエラーと対処法

| エラー | 原因 | 対処法 |
|--------|------|--------|
| `ROLLBACK_COMPLETE` | リソース作成失敗 | ログ確認 → 修正 → 再デプロイ |
| `UPDATE_ROLLBACK_COMPLETE` | 更新失敗 | Change Set の diff を確認 → 修正 |
| `DELETE_FAILED` | 依存リソースが残っている | 依存関係を確認 → 手動削除 |
| `CAPABILITY_IAM` エラー | IAM 権限不足 | `--capabilities CAPABILITY_IAM` を追加 |

### 6.2 ロールバック手順

**自動ロールバック**:
- CloudFormation が自動的に前のバージョンに戻す
- `UPDATE_ROLLBACK_COMPLETE` ステータスになる

**手動ロールバック**:

```bash
# 方法1: スクリプト使用
./scripts/rollback.sh niigata-kaigo-staging-network-stack

# 方法2: AWS CLI 直接実行
aws cloudformation cancel-update-stack \
  --stack-name niigata-kaigo-staging-network-stack

aws cloudformation wait stack-rollback-complete \
  --stack-name niigata-kaigo-staging-network-stack
```

---

## 7. モニタリングとアラート

### 7.1 デプロイ監視

**CloudWatch Events で監視**:

```yaml
# templates/monitoring/eventbridge-rules.yaml
Resources:
  StackDeploymentEventRule:
    Type: AWS::Events::Rule
    Properties:
      Description: 'Notify on CloudFormation stack changes'
      EventPattern:
        source:
          - aws.cloudformation
        detail-type:
          - CloudFormation Stack Status Change
        detail:
          status-details:
            status:
              - CREATE_COMPLETE
              - UPDATE_COMPLETE
              - ROLLBACK_COMPLETE
              - UPDATE_ROLLBACK_COMPLETE
      Targets:
        - Arn: !Ref SNSTopicForAlerts
          Id: CloudFormationStackStatusChange
```

### 7.2 アラート通知

**SNS トピックでSlack/Email通知**:

```bash
# デプロイ成功
✅ [Staging] Network Stack deployment completed successfully

# デプロイ失敗
❌ [Staging] Network Stack deployment failed
   Status: UPDATE_ROLLBACK_COMPLETE
   Reason: Resource creation failed
   Action: Check CloudWatch Logs for details
```

---

## 8. まとめ

### 8.1 デプロイ手順（再掲）

```
1. Change Set 作成（dry-run）
   ↓
2. Change Set 内容確認（レビュー）
   ↓
3. ユーザー承認
   ↓
4. Change Set 実行（本番デプロイ）
```

### 8.2 4つのスクリプト（再掲）

| スクリプト | 役割 |
|-----------|------|
| `create-changeset.sh` | Change Set 作成 |
| `describe-changeset.sh` | Change Set 内容確認 |
| `execute-changeset.sh` | Change Set 実行 |
| `rollback.sh` | ロールバック |

### 8.3 実装フェーズでの注意事項

1. **Change Sets 必須**: 本番環境への直接デプロイ禁止
2. **段階的デプロイ**: ライフサイクルの長いスタックから順にデプロイ
3. **ロールバック手順**: 必ず確認しておく
4. **モニタリング**: CloudWatch Events でデプロイ監視

---

**関連ドキュメント**:
- [cloudformation_structure.md](./cloudformation_structure.md) - ファイル分割3原則とディレクトリ構造
- [stack_lifecycle.md](./stack_lifecycle.md) - スタックライフサイクル管理
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` - CloudFormation 技術標準
