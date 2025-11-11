#!/bin/bash
# =============================================================================
# deploy-app-monitoring.sh
# App Account 監視スタックをデプロイするスクリプト
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
Usage: $0 <environment> [--vpc-id VPC_ID]

Arguments:
  environment       環境名（dev, staging, または production）
  --vpc-id          VPC ID（オプション。省略時はパラメータファイルから取得）

Example:
  $0 dev --vpc-id vpc-0123456789abcdef0
  $0 staging
  $0 production --vpc-id vpc-0123456789abcdef0

Description:
  App Account の監視スタック (09-monitoring) をデプロイします。

  デプロイされるリソース:
  - App SNS Topics (Critical, Warning, Info)
  - App CloudWatch Log Groups (ECS, RDS, ALB)
  - VPC Flow Logs (GCAS Requirement)
  - CloudWatch Alarms (ALB, ECS, RDS, ElastiCache)
  - AWS Backup Plan (RDS, EBS)

  Change Sets を使用するため、dry-run で変更内容を確認してから実行できます。

  ⚠️  VPC スタックが事前にデプロイされている必要があります。

EOF
  exit 1
}

# 引数パース
if [ $# -lt 1 ]; then
  echo -e "${RED}❌ Error: 引数が不足しています${NC}"
  usage
fi

ENVIRONMENT=$1
shift

VPC_ID=""

# オプション引数をパース
while [[ $# -gt 0 ]]; do
  case $1 in
    --vpc-id)
      VPC_ID="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}❌ Error: 不明なオプション: $1${NC}"
      usage
      ;;
  esac
done

# 環境名のバリデーション
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "dev" ]]; then
  echo -e "${RED}❌ Error: 環境名は 'production', 'staging', または 'dev' である必要があります${NC}"
  exit 1
fi

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

# スタック名とファイルパス
STACK_NAME="niigata-kaigo-${ENVIRONMENT}-app-monitoring"
TEMPLATE_FILE="infra/app/cloudformation/stacks/09-monitoring/main.yaml"
PARAMETERS_FILE="infra/app/cloudformation/parameters/${ENVIRONMENT}/09-monitoring-stack-params.json"

echo -e "${GREEN}========================================"
echo "App Account Monitoring Stack Deploy"
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

# VPC ID が指定されていない場合、VPC スタックから取得
if [ -z "$VPC_ID" ]; then
  echo -e "${YELLOW}ℹ️  VPC ID が指定されていません。VPC スタックから取得します...${NC}"

  VPC_STACK_NAME="niigata-kaigo-${ENVIRONMENT}-app-network"

  set +e
  VPC_ID=$(aws cloudformation describe-stacks \
    --stack-name "${VPC_STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`AppVPCId`].OutputValue' \
    --output text 2>&1)
  VPC_STATUS=$?
  set -e

  if [ $VPC_STATUS -ne 0 ] || [ -z "$VPC_ID" ]; then
    echo -e "${RED}❌ Error: VPC スタック (${VPC_STACK_NAME}) が見つかりません${NC}"
    echo ""
    echo "VPC スタックを先にデプロイするか、--vpc-id オプションで VPC ID を指定してください。"
    exit 1
  fi

  echo -e "${GREEN}✅ VPC ID を取得しました: ${VPC_ID}${NC}"
fi

# パラメータファイルを一時的に更新（VPC ID を設定）
TEMP_PARAMETERS_FILE=$(mktemp)
jq --arg vpc_id "$VPC_ID" \
  '(.[] | select(.ParameterKey == "VPCId") | .ParameterValue) |= $vpc_id' \
  "$PARAMETERS_FILE" > "$TEMP_PARAMETERS_FILE"

echo "VPC ID: ${VPC_ID}"
echo ""

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
  --parameters "file://${TEMP_PARAMETERS_FILE}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --tags \
    Key=Environment,Value="${ENVIRONMENT}" \
    Key=ManagedBy,Value=CloudFormation \
    Key=Project,Value=NiigataKaigoSystem \
    Key=Account,Value=App \
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
      rm -f "$TEMP_PARAMETERS_FILE"
      exit 0
    else
      echo -e "${RED}❌ Change Set 作成に失敗しました${NC}"
      rm -f "$TEMP_PARAMETERS_FILE"
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
  rm -f "$TEMP_PARAMETERS_FILE"
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

# 一時ファイルをクリーンアップ
rm -f "$TEMP_PARAMETERS_FILE"

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
echo "1. SNS トピックのメールサブスクリプションを確認："
echo "   受信トレイを確認して、AWS SNS からのサブスクリプション確認メールを承認してください。"
echo ""
echo "2. VPC Flow Logs が記録されているか確認："
echo "   aws logs tail /aws/vpc/flowlogs/niigata-kaigo-${ENVIRONMENT}-app-vpc --follow"
echo ""
echo "3. CloudWatch Alarms が作成されているか確認："
echo "   aws cloudwatch describe-alarms --region ${AWS_REGION}"
echo ""
echo "4. AWS Backup Plan が作成されているか確認："
echo "   aws backup list-backup-plans --region ${AWS_REGION}"
echo ""
