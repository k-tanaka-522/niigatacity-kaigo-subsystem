#!/bin/bash
# =============================================================================
# delete-changeset.sh
# CloudFormation Change Set を削除するスクリプト
#
# Change Setを削除しても、スタック自体は削除されません。
# Change Setの削除は無料です。
# =============================================================================

set -euo pipefail

# 使い方
usage() {
  cat <<EOF
Usage: $0 <stack-name> <changeset-name> <environment>

Arguments:
  stack-name        CloudFormation スタック名
  changeset-name    Change Set 名
  environment       環境名（production, staging, または dev）

Example:
  $0 niigata-kaigo-staging-network-stack \\
    niigata-kaigo-staging-network-stack-changeset-20251109-143000 \\
    staging

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 3 ]; then
  echo "❌ Error: 引数が不足しています"
  usage
fi

STACK_NAME=$1
CHANGESET_NAME=$2
ENVIRONMENT=$3

# 環境名のバリデーション
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "dev" ]]; then
  echo "❌ Error: 環境名は 'production', 'staging', または 'dev' である必要があります"
  exit 1
fi

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

# 環境ごとのAWS Profileを設定
get_aws_profile() {
  local environment=$1
  local stack_name=$2

  # スタック名からアカウント種別を判定
  if [[ "$stack_name" == *"-common-"* ]]; then
    case "${environment}" in
      production) echo "niigata-kaigo-production-common" ;;
      staging) echo "niigata-kaigo-staging-common" ;;
      dev) echo "default" ;;
      *) echo "default" ;;
    esac
  else
    case "${environment}" in
      production) echo "niigata-kaigo-production-app" ;;
      staging) echo "niigata-kaigo-staging-app" ;;
      dev) echo "default" ;;
      *) echo "default" ;;
    esac
  fi
}

AWS_PROFILE=$(get_aws_profile "${ENVIRONMENT}" "${STACK_NAME}")
export AWS_PROFILE

echo "========================================"
echo "CloudFormation Change Set 削除"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Change Set: ${CHANGESET_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "AWS Profile: ${AWS_PROFILE}"
echo "Account ID: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: ${AWS_REGION}"
echo ""

# Change Setが存在するか確認
set +e
aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  > /dev/null 2>&1
CHANGESET_EXISTS=$?
set -e

if [ $CHANGESET_EXISTS -ne 0 ]; then
  echo "❌ Error: Change Set not found"
  echo "   Stack: ${STACK_NAME}"
  echo "   Change Set: ${CHANGESET_NAME}"
  exit 1
fi

echo "✅ Change Set found"
echo ""

# 確認
echo "⚠️  Warning: This will delete the Change Set"
echo "   The stack itself will NOT be deleted"
echo ""
read -p "Delete this Change Set? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

# Change Set 削除
echo ""
echo "Deleting Change Set: ${CHANGESET_NAME}"
echo ""

aws cloudformation delete-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}"

echo ""
echo "✅ Change Set deleted successfully: ${CHANGESET_NAME}"
echo ""
echo "Note: The stack ${STACK_NAME} still exists"
echo "To delete the stack, use:"
echo "  ./scripts/delete-stack.sh ${STACK_NAME} ${ENVIRONMENT}"
echo ""
