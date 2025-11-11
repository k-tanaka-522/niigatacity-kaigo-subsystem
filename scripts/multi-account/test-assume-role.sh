#!/bin/bash
# =============================================================================
# test-assume-role.sh
# AssumeRoleが正常に動作するかテスト
#
# Purpose:
# - assume-role.sh を呼び出し、AssumeRoleが成功するか確認
# - 認証情報が正しく設定されているか確認
# - テスト結果を分かりやすく表示
#
# Usage:
#   ./scripts/multi-account/test-assume-role.sh <environment> <account-type>
#
# Arguments:
#   environment   - 環境名（production, staging, dev）
#   account-type  - アカウント種別（common, app）
#
# Example:
#   ./scripts/multi-account/test-assume-role.sh production common
#   ./scripts/multi-account/test-assume-role.sh staging app
# =============================================================================

set -euo pipefail

# カラーコード定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 使い方
usage() {
  cat <<EOF
Usage: $0 <environment> <account-type>

Arguments:
  environment   - 環境名（production, staging, dev）
  account-type  - アカウント種別（common, app）

Example:
  $0 production common
  $0 staging app
  $0 dev common

EOF
  exit 1
}

# 引数チェック
if [ $# -ne 2 ]; then
  echo -e "${RED}❌ Error: 引数が不足しています${NC}"
  usage
fi

TEST_ENVIRONMENT=$1
TEST_ACCOUNT_TYPE=$2

# 環境名のバリデーション
if [[ "$TEST_ENVIRONMENT" != "production" && "$TEST_ENVIRONMENT" != "staging" && "$TEST_ENVIRONMENT" != "dev" ]]; then
  echo -e "${RED}❌ Error: 環境名は 'production', 'staging', または 'dev' である必要があります${NC}"
  exit 1
fi

# アカウント種別のバリデーション
if [[ "$TEST_ACCOUNT_TYPE" != "common" && "$TEST_ACCOUNT_TYPE" != "app" ]]; then
  echo -e "${RED}❌ Error: アカウント種別は 'common' または 'app' である必要があります${NC}"
  exit 1
fi

echo "========================================"
echo "AssumeRole テスト"
echo "========================================"
echo "Environment: ${TEST_ENVIRONMENT}"
echo "Account Type: ${TEST_ACCOUNT_TYPE}"
echo ""

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# 実行前の認証情報を保存
BEFORE_ACCESS_KEY="${AWS_ACCESS_KEY_ID:-<not set>}"
BEFORE_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "<not authenticated>")

echo "実行前の認証情報:"
echo "  Account ID: ${BEFORE_ACCOUNT_ID}"
echo ""

# AssumeRole実行
echo "AssumeRole実行中..."
echo ""

# assume-role.sh を source して実行
# サブシェルではなく現在のシェルで実行（環境変数をエクスポートするため）
set +e
source "${SCRIPT_DIR}/assume-role.sh" "$TEST_ENVIRONMENT" "$TEST_ACCOUNT_TYPE"
ASSUME_RESULT=$?
set -e

echo ""

# 結果判定
if [ $ASSUME_RESULT -ne 0 ]; then
  echo -e "${RED}========================================"
  echo "❌ AssumeRole失敗"
  echo "========================================${NC}"
  echo ""
  echo "原因:"
  echo "  - IAM Roleが存在しない"
  echo "  - 信頼関係が正しく設定されていない"
  echo "  - External IDが正しくない"
  echo "  - 権限が不足している"
  echo ""
  exit 1
fi

# 実行後の認証情報を確認
AFTER_ACCESS_KEY="${AWS_ACCESS_KEY_ID:-<not set>}"
AFTER_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "<not authenticated>")

echo -e "${GREEN}========================================"
echo "✅ AssumeRole成功"
echo "========================================${NC}"
echo ""
echo "実行後の認証情報:"
echo "  Account ID: ${AFTER_ACCOUNT_ID}"
echo ""

# 認証情報が変わったか確認（ローカル実行時はProfileのみなので変わらない）
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  echo "ℹ️  ローカル実行モード: AWS Profileによる認証"
  echo "ℹ️  セッショントークンは設定されません"
else
  if [ "$AFTER_ACCESS_KEY" = "$BEFORE_ACCESS_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: 認証情報が変わっていません${NC}"
  else
    echo -e "${GREEN}✅ 認証情報が更新されました${NC}"
  fi

  # セッショントークンが設定されているか確認
  if [ -z "${AWS_SESSION_TOKEN:-}" ]; then
    echo -e "${YELLOW}⚠️  Warning: セッショントークンが設定されていません${NC}"
  else
    echo -e "${GREEN}✅ セッショントークンが設定されています${NC}"
  fi
fi

echo ""
echo "========================================"
echo "詳細情報"
echo "========================================"
echo ""

# 詳細な認証情報を表示
aws sts get-caller-identity --output table

echo ""
echo -e "${GREEN}✅ テスト完了${NC}"
echo ""
