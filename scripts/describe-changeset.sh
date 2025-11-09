#!/bin/bash
# =============================================================================
# describe-changeset.sh
# CloudFormation Change Set の内容を確認するスクリプト
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
echo "CloudFormation Change Set Details"
echo "========================================"
echo "Stack: ${STACK_NAME}"
echo "Change Set: ${CHANGESET_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

# Change Set の状態を確認
echo "Change Set Status:"
echo "---"
aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  --query '{Status: Status, StatusReason: StatusReason, ExecutionStatus: ExecutionStatus}' \
  --output table

echo ""
echo "========================================"
echo "Changes Preview"
echo "========================================"
echo ""

# 変更内容を表示
aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Changes[*].{Action: ResourceChange.Action, LogicalResourceId: ResourceChange.LogicalResourceId, ResourceType: ResourceChange.ResourceType, Replacement: ResourceChange.Replacement, Scope: ResourceChange.Scope}' \
  --output table

echo ""
echo "========================================"
echo "Review Instructions"
echo "========================================"
echo ""
echo "1. ✅ 変更内容を確認してください"
echo "   - Action: Add (追加), Modify (変更), Remove (削除)"
echo "   - Replacement: True (リソース置換あり), False (リソース置換なし)"
echo ""
echo "2. ⚠️  Replacement: True の場合は要注意"
echo "   - リソースが削除→再作成されます"
echo "   - データベース、Elastic IP など、データが失われる可能性があります"
echo ""
echo "3. 📝 変更内容が正しい場合:"
echo "   ./scripts/execute-changeset.sh ${STACK_NAME} ${CHANGESET_NAME}"
echo ""
echo "4. ❌ 変更内容が正しくない場合:"
echo "   aws cloudformation delete-change-set \\"
echo "     --stack-name ${STACK_NAME} \\"
echo "     --change-set-name ${CHANGESET_NAME} \\"
echo "     --region ${AWS_REGION}"
echo ""
echo "5. 📄 詳細なJSON出力が必要な場合:"
echo "   aws cloudformation describe-change-set \\"
echo "     --stack-name ${STACK_NAME} \\"
echo "     --change-set-name ${CHANGESET_NAME} \\"
echo "     --region ${AWS_REGION}"
echo ""
