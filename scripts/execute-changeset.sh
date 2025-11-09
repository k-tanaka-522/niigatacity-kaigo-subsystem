#!/bin/bash
# =============================================================================
# execute-changeset.sh
# CloudFormation Change Set を実行するスクリプト
# =============================================================================

set -euo pipefail

# 使い方
usage() {
  cat <<EOF
Usage: $0 <stack-name> <changeset-name>

Arguments:
  stack-name        CloudFormation スタック名
  changeset-name    Change Set 名

Example:
  $0 niigata-kaigo-staging-network-stack \\
    niigata-kaigo-staging-network-stack-changeset-20251109-143000

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 2 ]; then
  echo "❌ Error: 引数が不足しています"
  usage
fi

STACK_NAME=$1
CHANGESET_NAME=$2

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

echo "========================================"
echo "CloudFormation Change Set 実行"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Change Set: ${CHANGESET_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

# Change Set の状態を確認
echo "Checking Change Set status..."
CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Status' \
  --output text)

if [ "$CHANGE_SET_STATUS" != "CREATE_COMPLETE" ]; then
  echo "❌ Error: Change Set のステータスが CREATE_COMPLETE ではありません: $CHANGE_SET_STATUS"
  exit 1
fi

# 変更内容を再度表示
echo ""
echo "========================================"
echo "Changes to be applied:"
echo "========================================"
echo ""

aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Changes[*].{Action: ResourceChange.Action, LogicalResourceId: ResourceChange.LogicalResourceId, ResourceType: ResourceChange.ResourceType, Replacement: ResourceChange.Replacement}' \
  --output table

echo ""
echo "========================================"
echo "⚠️  WARNING"
echo "========================================"
echo ""
echo "この Change Set を実行すると、上記の変更が本番環境に適用されます。"
echo ""

# 確認プロンプト
read -p "本当に実行しますか？ (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo ""
  echo "❌ Change Set の実行がキャンセルされました。"
  exit 1
fi

echo ""
echo "Executing Change Set..."
echo ""

# Change Set を実行
aws cloudformation execute-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}"

echo ""
echo "✅ Change Set execution started."
echo ""
echo "Waiting for stack operation to complete..."
echo ""

# スタック操作の完了を待つ
# CREATE か UPDATE かを判定
set +e
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].StackStatus' \
  --output text | grep -q "CREATE_IN_PROGRESS"
IS_CREATE=$?
set -e

if [ $IS_CREATE -eq 0 ]; then
  # CREATE の場合
  echo "Waiting for stack creation to complete..."
  aws cloudformation wait stack-create-complete \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}"
else
  # UPDATE の場合
  echo "Waiting for stack update to complete..."
  aws cloudformation wait stack-update-complete \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}"
fi

echo ""
echo "========================================"
echo "✅ Stack operation completed successfully!"
echo "========================================"
echo ""

# スタックの状態を表示
echo "Stack Status:"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].{StackName: StackName, Status: StackStatus, CreationTime: CreationTime, LastUpdatedTime: LastUpdatedTime}' \
  --output table

echo ""
echo "Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "1. 動作確認を実施してください"
echo "2. 問題がある場合はロールバックを検討してください:"
echo "   ./scripts/rollback.sh ${STACK_NAME}"
echo ""
