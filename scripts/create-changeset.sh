#!/bin/bash
# =============================================================================
# create-changeset.sh
# CloudFormation Change Set を作成するスクリプト
# =============================================================================

set -euo pipefail

# 使い方
usage() {
  cat <<EOF
Usage: $0 <stack-name> <template-file> <parameters-file> <environment>

Arguments:
  stack-name        CloudFormation スタック名
  template-file     CloudFormation テンプレートファイルパス
  parameters-file   パラメーターファイルパス（JSON形式）
  environment       環境名（production または staging）

Example:
  $0 niigata-kaigo-staging-network-stack \\
    infra/cloudformation/stacks/02-network/main.yaml \\
    infra/cloudformation/parameters/staging.json \\
    staging

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 4 ]; then
  echo "❌ Error: 引数が不足しています"
  usage
fi

STACK_NAME=$1
TEMPLATE_FILE=$2
PARAMETERS_FILE=$3
ENVIRONMENT=$4
CHANGESET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

# 環境名のバリデーション
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
  echo "❌ Error: 環境名は 'production' または 'staging' である必要があります"
  exit 1
fi

# ファイル存在チェック
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ Error: テンプレートファイルが見つかりません: $TEMPLATE_FILE"
  exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
  echo "❌ Error: パラメーターファイルが見つかりません: $PARAMETERS_FILE"
  exit 1
fi

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

echo "========================================"
echo "CloudFormation Change Set 作成"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Template: ${TEMPLATE_FILE}"
echo "Parameters: ${PARAMETERS_FILE}"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "Change Set: ${CHANGESET_NAME}"
echo ""

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
  echo "ℹ️  既存スタックを更新します"
else
  CHANGE_SET_TYPE="CREATE"
  echo "ℹ️  新規スタックを作成します"
fi

# Change Set 作成
echo ""
echo "Creating Change Set: ${CHANGESET_NAME}"
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
  --region "${AWS_REGION}"

echo ""
echo "Waiting for Change Set to be created..."
echo ""

# Change Set 作成完了を待つ
aws cloudformation wait change-set-create-complete \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}"

echo ""
echo "✅ Change Set created successfully: ${CHANGESET_NAME}"
echo ""
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "1. Review the Change Set:"
echo "   ./scripts/describe-changeset.sh ${STACK_NAME} ${CHANGESET_NAME}"
echo ""
echo "2. If changes look good, execute the Change Set:"
echo "   ./scripts/execute-changeset.sh ${STACK_NAME} ${CHANGESET_NAME}"
echo ""
echo "3. If changes are NOT correct, delete the Change Set:"
echo "   aws cloudformation delete-change-set \\"
echo "     --stack-name ${STACK_NAME} \\"
echo "     --change-set-name ${CHANGESET_NAME} \\"
echo "     --region ${AWS_REGION}"
echo ""
