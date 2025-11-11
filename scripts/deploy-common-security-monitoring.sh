#!/bin/bash
# =============================================================================
# deploy-common-security-monitoring.sh
# Common Account セキュリティ監視スタックをデプロイするスクリプト
# Change Sets を使用した安全なデプロイ
# =============================================================================

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 使い方
usage() {
  cat <<EOF
Usage: $0 <environment>

Arguments:
  environment       環境名（production または staging）

Example:
  $0 production
  $0 staging

Description:
  Common Account のセキュリティ監視スタック (03-security-monitoring) をデプロイします。

  デプロイされるリソース:
  - Security Log Buckets (CloudTrail, Config, VPC Flow Logs, ALB Logs)
  - Security SNS Topics (Critical, Warning, Info)
  - CloudTrail (Organization Trail)
  - AWS Config (Compliance Monitoring)
  - GuardDuty + Security Hub (Threat Detection)

  Change Sets を使用するため、dry-run で変更内容を確認してから実行できます。

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 1 ]; then
  echo -e "${RED}❌ Error: 引数が不足しています${NC}"
  usage
fi

ENVIRONMENT=$1

# 環境名のバリデーション
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
  echo -e "${RED}❌ Error: 環境名は 'production' または 'staging' である必要があります${NC}"
  exit 1
fi

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

# スタック名とファイルパス
STACK_NAME="niigata-kaigo-${ENVIRONMENT}-common-security-monitoring"
TEMPLATE_FILE="infra/common/cloudformation/stacks/03-security-monitoring/main.yaml"
PARAMETERS_FILE="infra/common/cloudformation/parameters/${ENVIRONMENT}/03-security-monitoring-stack-params.json"

echo -e "${GREEN}========================================"
echo "Common Account Security Monitoring Stack Deploy"
echo -e "========================================${NC}"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Name: ${STACK_NAME}"
echo "Template: ${TEMPLATE_FILE}"
echo "Parameters: ${PARAMETERS_FILE}"
echo "Region: ${AWS_REGION}"
echo ""

# ファイル存在チェック
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo -e "${RED}❌ Error: テンプレートファイルが見つかりません: ${TEMPLATE_FILE}${NC}"
  exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
  echo -e "${RED}❌ Error: パラメーターファイルが見つかりません: ${PARAMETERS_FILE}${NC}"
  exit 1
fi

# Change Set 名
CHANGESET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

# スタックが既に存在するか確認
set +e
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  > /dev/null 2>&1
STACK_EXISTS=$?
set -e

if [ $STACK_EXISTS -eq 0 ]; then
  CHANGE_SET_TYPE="UPDATE"
  echo -e "${YELLOW}ℹ️  既存スタックを更新します${NC}"
else
  CHANGE_SET_TYPE="CREATE"
  echo -e "${YELLOW}ℹ️  新規スタックを作成します${NC}"
fi

# ========================================
# Step 1: Change Set 作成
# ========================================
echo ""
echo -e "${GREEN}Step 1: Change Set を作成しています...${NC}"
echo ""

aws cloudformation create-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --change-set-type "${CHANGE_SET_TYPE}" \
  --template-body "file://${TEMPLATE_FILE}" \
  --parameters "file://${PARAMETERS_FILE}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --tags \
    Key=Environment,Value="${ENVIRONMENT}" \
    Key=ManagedBy,Value=CloudFormation \
    Key=Project,Value=NiigataKaigoSystem \
    Key=Account,Value=Common \
  --region "${AWS_REGION}"

echo ""
echo -e "${YELLOW}Change Set 作成完了を待っています...${NC}"
echo ""

# Change Set 作成完了を待つ
aws cloudformation wait change-set-create-complete \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" 2>&1 | tee /tmp/changeset-wait.log || {
    if grep -q "No changes to deploy" /tmp/changeset-wait.log; then
      echo -e "${YELLOW}ℹ️  変更がありません。デプロイをスキップします。${NC}"
      aws cloudformation delete-change-set \
        --stack-name "${STACK_NAME}" \
        --change-set-name "${CHANGESET_NAME}" \
        --region "${AWS_REGION}"
      exit 0
    else
      echo -e "${RED}❌ Change Set 作成に失敗しました${NC}"
      exit 1
    fi
  }

echo -e "${GREEN}✅ Change Set 作成完了: ${CHANGESET_NAME}${NC}"

# ========================================
# Step 2: Change Set の内容を表示
# ========================================
echo ""
echo -e "${GREEN}Step 2: Change Set の内容を確認しています...${NC}"
echo ""

aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Changes[*].[Type, ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType, ResourceChange.Replacement]' \
  --output table

# ========================================
# Step 3: ユーザー承認
# ========================================
echo ""
echo -e "${YELLOW}========================================"
echo "Change Set の内容を確認してください"
echo -e "========================================${NC}"
echo ""
read -p "この Change Set を実行しますか？ (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo ""
  echo -e "${YELLOW}⚠️  デプロイをキャンセルしました${NC}"
  echo ""
  echo "Change Set を削除するには、以下のコマンドを実行してください："
  echo "  aws cloudformation delete-change-set \\"
  echo "    --stack-name ${STACK_NAME} \\"
  echo "    --change-set-name ${CHANGESET_NAME} \\"
  echo "    --region ${AWS_REGION}"
  exit 0
fi

# ========================================
# Step 4: Change Set 実行
# ========================================
echo ""
echo -e "${GREEN}Step 4: Change Set を実行しています...${NC}"
echo ""

aws cloudformation execute-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}"

echo ""
echo -e "${YELLOW}スタック更新完了を待っています...${NC}"
echo ""

# スタック更新完了を待つ
if [ "$CHANGE_SET_TYPE" == "CREATE" ]; then
  aws cloudformation wait stack-create-complete \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}"
else
  aws cloudformation wait stack-update-complete \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}"
fi

# ========================================
# Step 5: デプロイ結果の確認
# ========================================
echo ""
echo -e "${GREEN}✅ デプロイが完了しました！${NC}"
echo ""
echo -e "${GREEN}========================================"
echo "デプロイ結果"
echo -e "========================================${NC}"

aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].[StackName, StackStatus, CreationTime, LastUpdatedTime]' \
  --output table

echo ""
echo -e "${GREEN}Outputs:${NC}"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue, Description]' \
  --output table

echo ""
echo -e "${GREEN}========================================"
echo "次のステップ"
echo -e "========================================${NC}"
echo ""
echo "1. CloudTrail ログが記録されているか確認："
echo "   aws s3 ls s3://niigata-kaigo-${ENVIRONMENT}-common-cloudtrail-logs/"
echo ""
echo "2. AWS Config が有効化されているか確認："
echo "   aws configservice describe-configuration-recorders --region ${AWS_REGION}"
echo ""
echo "3. GuardDuty が有効化されているか確認："
echo "   aws guardduty list-detectors --region ${AWS_REGION}"
echo ""
echo "4. Security Hub が有効化されているか確認："
echo "   aws securityhub describe-hub --region ${AWS_REGION}"
echo ""
