#!/bin/bash
# =============================================================================
# get-account-id.sh
# 環境・アカウント種別からAWSアカウントIDを取得
#
# Purpose:
# - GitHub Actions実行時: 環境変数からアカウントIDを取得
# - ローカル実行時: account-mapping.json からアカウントIDを取得
#
# Usage:
#   ACCOUNT_ID=$(./scripts/multi-account/get-account-id.sh <environment> <account-type>)
#
# Arguments:
#   environment   - 環境名（production, staging, dev）
#   account-type  - アカウント種別（common, app）
#
# Environment Variables (GitHub Actions):
#   AWS_PROD_COMMON_ACCOUNT_ID      - Production Common Account ID
#   AWS_PROD_APP_ACCOUNT_ID         - Production App Account ID
#   AWS_STAGING_COMMON_ACCOUNT_ID   - Staging Common Account ID
#   AWS_STAGING_APP_ACCOUNT_ID      - Staging App Account ID
#
# Example:
#   ACCOUNT_ID=$(./scripts/multi-account/get-account-id.sh production common)
#   echo "Account ID: ${ACCOUNT_ID}"
# =============================================================================

set -euo pipefail

# 引数チェック
if [ $# -ne 2 ]; then
  echo "Error: 引数が不足しています | Missing arguments" >&2
  echo "Usage: $0 <environment> <account-type>" >&2
  echo "  environment: production, staging, dev" >&2
  echo "  account-type: common, app" >&2
  exit 1
fi

ENVIRONMENT=$1
ACCOUNT_TYPE=$2

# 環境名のバリデーション
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Error: 環境名は 'production', 'staging', または 'dev' である必要があります" >&2
  echo "Error: Environment must be 'production', 'staging', or 'dev'" >&2
  exit 1
fi

# アカウント種別のバリデーション
if [[ "$ACCOUNT_TYPE" != "common" && "$ACCOUNT_TYPE" != "app" ]]; then
  echo "Error: アカウント種別は 'common' または 'app' である必要があります" >&2
  echo "Error: Account type must be 'common' or 'app'" >&2
  exit 1
fi

# GitHub Actions実行時: 環境変数からアカウントIDを取得
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  # 環境変数名を構築
  ENV_VAR_NAME="AWS_${ENVIRONMENT^^}_${ACCOUNT_TYPE^^}_ACCOUNT_ID"

  # 環境変数から取得（間接参照）
  ACCOUNT_ID="${!ENV_VAR_NAME:-}"

  if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: 環境変数 ${ENV_VAR_NAME} が設定されていません" >&2
    echo "Error: Environment variable ${ENV_VAR_NAME} is not set" >&2
    exit 1
  fi

  echo "$ACCOUNT_ID"
  exit 0
fi

# ローカル実行時: account-mapping.json から取得
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAPPING_FILE="${SCRIPT_DIR}/account-mapping.json"

if [ ! -f "$MAPPING_FILE" ]; then
  echo "Error: アカウントマッピングファイルが見つかりません: ${MAPPING_FILE}" >&2
  echo "Error: Account mapping file not found: ${MAPPING_FILE}" >&2
  exit 1
fi

# jq コマンドで JSON からアカウントIDを取得
ACCOUNT_ID=$(jq -r ".${ENVIRONMENT}.${ACCOUNT_TYPE}" "$MAPPING_FILE")

if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "null" ]; then
  echo "Error: アカウントIDが見つかりません (環境: ${ENVIRONMENT}, 種別: ${ACCOUNT_TYPE})" >&2
  echo "Error: Account ID not found (environment: ${ENVIRONMENT}, type: ${ACCOUNT_TYPE})" >&2
  exit 1
fi

echo "$ACCOUNT_ID"
