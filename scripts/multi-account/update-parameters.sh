#!/bin/bash
# =============================================================================
# update-parameters.sh
# Common AccountのスタックOutputsからTransit Gateway IDを取得し、
# App Accountのパラメーターファイルに注入
#
# Purpose:
# - Multi-Account構成でのパラメーター共有
# - Common Account → App Account へのOutputs連携
# - Transit Gateway ID, Route Table ID などを自動設定
#
# Usage:
#   ./scripts/multi-account/update-parameters.sh <environment>
#
# Arguments:
#   environment   - 環境名（production, staging, dev）
#
# Example:
#   ./scripts/multi-account/update-parameters.sh production
#   ./scripts/multi-account/update-parameters.sh staging
# =============================================================================

set -euo pipefail

# 使い方
usage() {
  cat <<EOF
Usage: $0 <environment>

Arguments:
  environment   - 環境名（production, staging, dev）

Example:
  $0 production
  $0 staging
  $0 dev

Description:
  Common AccountのNetwork Stackから以下のOutputsを取得し、
  App Accountのパラメーターファイルに注入します:
    - TransitGatewayId
    - TransitGatewayRouteTableId

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 1 ]; then
  echo "❌ Error: 引数が不足しています"
  usage
fi

UPDATE_ENVIRONMENT=$1

# 環境名のバリデーション
if [[ "$UPDATE_ENVIRONMENT" != "production" && "$UPDATE_ENVIRONMENT" != "staging" && "$UPDATE_ENVIRONMENT" != "dev" ]]; then
  echo "❌ Error: 環境名は 'production', 'staging', または 'dev' である必要があります"
  exit 1
fi

# AWS リージョン設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

echo "========================================"
echo "パラメーターファイル更新"
echo "========================================"
echo "Environment: ${UPDATE_ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo ""

# パラメーターファイルのパス
COMMON_PARAMS_FILE="${PROJECT_ROOT}/infra/common/cloudformation/parameters/${UPDATE_ENVIRONMENT}.json"
APP_PARAMS_FILE="${PROJECT_ROOT}/infra/app/cloudformation/parameters/${UPDATE_ENVIRONMENT}.json"

# ファイル存在チェック
if [ ! -f "$APP_PARAMS_FILE" ]; then
  echo "❌ Error: App Accountのパラメーターファイルが見つかりません: ${APP_PARAMS_FILE}"
  exit 1
fi

echo "App Account パラメーターファイル: ${APP_PARAMS_FILE}"
echo ""

# Common Accountに切り替え（AssumeRole）
echo "Common Accountに接続中..."
source "${SCRIPT_DIR}/assume-role.sh" "$UPDATE_ENVIRONMENT" "common"
echo ""

# Common AccountのNetwork Stackからのスタック名
NETWORK_STACK_NAME="niigata-kaigo-${UPDATE_ENVIRONMENT}-network-stack"

echo "Common Account Network Stackから情報取得中..."
echo "Stack Name: ${NETWORK_STACK_NAME}"
echo ""

# スタックOutputsを取得
set +e
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name "${NETWORK_STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].Outputs' \
  --output json 2>&1)
DESCRIBE_EXIT_CODE=$?
set -e

if [ $DESCRIBE_EXIT_CODE -ne 0 ]; then
  echo "❌ Error: Common Account Network Stackが見つかりません"
  echo "Stack Name: ${NETWORK_STACK_NAME}"
  echo "Error: ${STACK_OUTPUTS}"
  exit 1
fi

# Transit Gateway IDを取得
TGW_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="TransitGatewayId") | .OutputValue')

# Transit Gateway Route Table IDを取得
TGW_RTB_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="TransitGatewayRouteTableId") | .OutputValue')

# 取得結果を表示
echo "取得したOutputs:"
echo "  TransitGatewayId: ${TGW_ID}"
echo "  TransitGatewayRouteTableId: ${TGW_RTB_ID}"
echo ""

# 値が取得できたか確認
if [ -z "$TGW_ID" ] || [ "$TGW_ID" = "null" ]; then
  echo "❌ Error: TransitGatewayId が取得できませんでした"
  exit 1
fi

if [ -z "$TGW_RTB_ID" ] || [ "$TGW_RTB_ID" = "null" ]; then
  echo "❌ Error: TransitGatewayRouteTableId が取得できませんでした"
  exit 1
fi

# App Accountに切り替え
echo "App Accountに接続中..."
source "${SCRIPT_DIR}/assume-role.sh" "$UPDATE_ENVIRONMENT" "app"
echo ""

# バックアップ作成
BACKUP_FILE="${APP_PARAMS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
echo "バックアップ作成: ${BACKUP_FILE}"
cp "$APP_PARAMS_FILE" "$BACKUP_FILE"
echo ""

# パラメーターファイルを更新
echo "パラメーターファイル更新中..."

# jq で TransitGatewayId を更新
TMP_FILE=$(mktemp)
jq --arg tgw_id "$TGW_ID" --arg tgw_rtb_id "$TGW_RTB_ID" '
  map(
    if .ParameterKey == "TransitGatewayId" then
      .ParameterValue = $tgw_id
    elif .ParameterKey == "TransitGatewayRouteTableId" then
      .ParameterValue = $tgw_rtb_id
    else
      .
    end
  )
' "$APP_PARAMS_FILE" > "$TMP_FILE"

# 更新を適用
mv "$TMP_FILE" "$APP_PARAMS_FILE"

echo "✅ パラメーターファイル更新完了"
echo ""

# 差分表示
echo "========================================"
echo "更新内容"
echo "========================================"
echo ""
echo "更新されたパラメーター:"
jq -r '.[] | select(.ParameterKey == "TransitGatewayId" or .ParameterKey == "TransitGatewayRouteTableId") | "  \(.ParameterKey): \(.ParameterValue)"' "$APP_PARAMS_FILE"
echo ""

echo "✅ 完了"
echo ""
echo "バックアップファイル: ${BACKUP_FILE}"
echo "更新されたファイル: ${APP_PARAMS_FILE}"
echo ""
