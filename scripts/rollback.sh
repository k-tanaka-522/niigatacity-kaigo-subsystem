#!/bin/bash
# =============================================================================
# rollback.sh
# CloudFormation スタックをロールバックするスクリプト
# =============================================================================

set -euo pipefail

# 使い方
usage() {
  cat <<EOF
Usage: $0 <stack-name>

Arguments:
  stack-name        CloudFormation スタック名

Example:
  $0 niigata-kaigo-staging-network-stack

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 1 ]; then
  echo "❌ Error: 引数が不足しています"
  usage
fi

STACK_NAME=$1

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

echo "========================================"
echo "CloudFormation Stack Rollback"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

# スタックの状態を確認
echo "Checking stack status..."
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].StackStatus' \
  --output text)

echo "Current Stack Status: ${STACK_STATUS}"
echo ""

# ロールバック可能な状態かチェック
if [[ "$STACK_STATUS" != "UPDATE_IN_PROGRESS" && "$STACK_STATUS" != "UPDATE_FAILED" && "$STACK_STATUS" != "UPDATE_ROLLBACK_FAILED" ]]; then
  echo "❌ Error: ロールバック可能な状態ではありません: $STACK_STATUS"
  echo ""
  echo "ロールバック可能な状態:"
  echo "  - UPDATE_IN_PROGRESS"
  echo "  - UPDATE_FAILED"
  echo "  - UPDATE_ROLLBACK_FAILED"
  exit 1
fi

# 最近の変更履歴を表示
echo "========================================"
echo "Recent Stack Events:"
echo "========================================"
echo ""

aws cloudformation describe-stack-events \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'StackEvents[0:10].{Timestamp: Timestamp, ResourceStatus: ResourceStatus, ResourceType: ResourceType, LogicalResourceId: LogicalResourceId, ResourceStatusReason: ResourceStatusReason}' \
  --output table

echo ""
echo "========================================"
echo "⚠️  WARNING"
echo "========================================"
echo ""
echo "ロールバックを実行すると、スタックは前の安定した状態に戻ります。"
echo "進行中の変更は全てキャンセルされます。"
echo ""

# 確認プロンプト
read -p "本当にロールバックしますか？ (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo ""
  echo "❌ ロールバックがキャンセルされました。"
  exit 1
fi

echo ""
echo "Initiating rollback..."
echo ""

# ロールバックを開始
aws cloudformation cancel-update-stack \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}"

echo "✅ Rollback initiated."
echo ""
echo "Waiting for rollback to complete..."
echo ""

# ロールバック完了を待つ
aws cloudformation wait stack-rollback-complete \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}"

echo ""
echo "========================================"
echo "✅ Rollback completed successfully!"
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
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "1. ロールバックの原因を調査してください"
echo "2. CloudWatch Logs でエラー詳細を確認してください"
echo "3. テンプレートまたはパラメーターを修正してください"
echo "4. 修正後、再度 Change Set を作成してください:"
echo "   ./scripts/create-changeset.sh <stack-name> <template> <parameters> <environment>"
echo ""
