#!/bin/bash
# =============================================================================
# generate-app-params.sh
#
# Common Stack の Outputs から App Stack のパラメータファイルを自動生成
#
# Usage:
#   ./scripts/generate-app-params.sh <environment>
#
# Example:
#   ./scripts/generate-app-params.sh staging
# =============================================================================

set -euo pipefail

# =============================================================================
# 引数チェック
# =============================================================================
if [ $# -lt 1 ]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 staging"
  exit 1
fi

ENVIRONMENT=$1
PROJECT_NAME="niigata-kaigo"
COMMON_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-common-network-stack"
PARAMS_FILE="infra/app/cloudformation/parameters/${ENVIRONMENT}/03-network-stack-params.json"

echo "========================================="
echo "App Parameters Auto-Generation"
echo "========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Common Stack: ${COMMON_STACK_NAME}"
echo "Output File: ${PARAMS_FILE}"
echo ""

# =============================================================================
# Common Stack の存在確認
# =============================================================================
echo "Checking Common Stack existence..."
set +e
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name ${COMMON_STACK_NAME} \
  --query 'Stacks[0].StackStatus' \
  --output text 2>&1)
set -e

if [[ "$STACK_STATUS" == *"does not exist"* ]]; then
  echo "❌ Error: Common Stack '${COMMON_STACK_NAME}' does not exist."
  echo "   Please deploy Common Stack first."
  exit 1
fi

if [[ "$STACK_STATUS" != "CREATE_COMPLETE" && "$STACK_STATUS" != "UPDATE_COMPLETE" ]]; then
  echo "⚠️  Warning: Common Stack status is '${STACK_STATUS}'"
  echo "   Expected: CREATE_COMPLETE or UPDATE_COMPLETE"
  read -p "Continue anyway? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

echo "✅ Common Stack found: ${STACK_STATUS}"
echo ""

# =============================================================================
# Common Stack の Outputs 取得
# =============================================================================
echo "Fetching Common Stack Outputs..."

TRANSIT_GATEWAY_ID=$(aws cloudformation describe-stacks \
  --stack-name ${COMMON_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text)

TRANSIT_GATEWAY_RT_ID=$(aws cloudformation describe-stacks \
  --stack-name ${COMMON_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayRouteTableId`].OutputValue' \
  --output text)

if [[ -z "$TRANSIT_GATEWAY_ID" || -z "$TRANSIT_GATEWAY_RT_ID" ]]; then
  echo "❌ Error: Could not fetch Transit Gateway Outputs from Common Stack."
  echo "   TransitGatewayId: ${TRANSIT_GATEWAY_ID}"
  echo "   TransitGatewayRouteTableId: ${TRANSIT_GATEWAY_RT_ID}"
  exit 1
fi

echo "✅ Transit Gateway ID: ${TRANSIT_GATEWAY_ID}"
echo "✅ Transit Gateway Route Table ID: ${TRANSIT_GATEWAY_RT_ID}"
echo ""

# =============================================================================
# パラメータファイルの読み込み
# =============================================================================
echo "Reading existing parameter file..."

if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "❌ Error: Parameter file not found: ${PARAMS_FILE}"
  exit 1
fi

# 既存のパラメータを保持しつつ、TransitGatewayId と TransitGatewayRouteTableId を更新
UPDATED_PARAMS=$(cat "$PARAMS_FILE" | jq --arg tgw_id "$TRANSIT_GATEWAY_ID" --arg tgw_rt_id "$TRANSIT_GATEWAY_RT_ID" '
  map(
    if .ParameterKey == "TransitGatewayId" then
      .ParameterValue = $tgw_id
    elif .ParameterKey == "TransitGatewayRouteTableId" then
      .ParameterValue = $tgw_rt_id
    else
      .
    end
  )
')

# =============================================================================
# パラメータファイルの更新
# =============================================================================
echo "Updating parameter file..."

echo "$UPDATED_PARAMS" > "$PARAMS_FILE"

echo "✅ Parameter file updated successfully!"
echo ""

# =============================================================================
# 更新内容の表示
# =============================================================================
echo "========================================="
echo "Updated Parameters:"
echo "========================================="
cat "$PARAMS_FILE" | jq .
echo ""

echo "========================================="
echo "✅ Success!"
echo "========================================="
echo "You can now deploy App Network Stack with updated parameters:"
echo ""
echo "  ./scripts/create-changeset.sh \\"
echo "    ${PROJECT_NAME}-${ENVIRONMENT}-app-network-stack \\"
echo "    infra/app/cloudformation/stacks/03-network/main.yaml \\"
echo "    ${PARAMS_FILE} \\"
echo "    ${ENVIRONMENT}"
echo ""
