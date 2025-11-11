#!/bin/bash
# =============================================================================
# assume-role.sh
# 指定されたアカウントにAssumeRoleして、認証情報を環境変数にエクスポート
#
# Purpose:
# - GitHub Actions実行時: CI/CD専用アカウントから各環境アカウントにAssumeRole
# - ローカル実行時: AWS Profile切り替え（AssumeRoleなし）
#
# Usage:
#   source ./scripts/multi-account/assume-role.sh <environment> <account-type>
#
# Arguments:
#   environment   - 環境名（production, staging, dev）
#   account-type  - アカウント種別（common, app）
#
# Environment Variables (Exported):
#   AWS_ACCESS_KEY_ID       - AssumeRole後のアクセスキー
#   AWS_SECRET_ACCESS_KEY   - AssumeRole後のシークレットキー
#   AWS_SESSION_TOKEN       - AssumeRole後のセッショントークン
#
# Environment Variables (Required for GitHub Actions):
#   GITHUB_ACTIONS          - GitHub Actions実行フラグ
#   GITHUB_RUN_ID           - GitHub Actions実行ID
#   AWS_EXTERNAL_ID         - External ID（Secrets設定）
#
# Example:
#   # GitHub Actions
#   source ./scripts/multi-account/assume-role.sh production common
#
#   # ローカル実行
#   source ./scripts/multi-account/assume-role.sh staging app
# =============================================================================

# sourceされているか確認（このスクリプトは直接実行不可）
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: このスクリプトは source コマンドで実行してください" >&2
  echo "Error: This script must be sourced, not executed directly" >&2
  echo "" >&2
  echo "Usage:" >&2
  echo "  source ./scripts/multi-account/assume-role.sh <environment> <account-type>" >&2
  exit 1
fi

# 引数チェック
if [ $# -ne 2 ]; then
  echo "Error: 引数が不足しています | Missing arguments" >&2
  echo "Usage: source $0 <environment> <account-type>" >&2
  echo "  environment: production, staging, dev" >&2
  echo "  account-type: common, app" >&2
  return 1
fi

ASSUME_ENVIRONMENT=$1
ASSUME_ACCOUNT_TYPE=$2

# 環境名のバリデーション
if [[ "$ASSUME_ENVIRONMENT" != "production" && "$ASSUME_ENVIRONMENT" != "staging" && "$ASSUME_ENVIRONMENT" != "dev" ]]; then
  echo "Error: 環境名は 'production', 'staging', または 'dev' である必要があります" >&2
  echo "Error: Environment must be 'production', 'staging', or 'dev'" >&2
  return 1
fi

# アカウント種別のバリデーション
if [[ "$ASSUME_ACCOUNT_TYPE" != "common" && "$ASSUME_ACCOUNT_TYPE" != "app" ]]; then
  echo "Error: アカウント種別は 'common' または 'app' である必要があります" >&2
  echo "Error: Account type must be 'common' or 'app'" >&2
  return 1
fi

# スクリプトのディレクトリを取得
ASSUME_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ローカル実行時: AWS Profile切り替え
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  echo "ℹ️  ローカル実行モード: AWS Profileを切り替えます"
  echo "ℹ️  Local execution mode: Switching AWS Profile"

  # AWS Profile名を構築
  AWS_PROFILE="niigata-kaigo-${ASSUME_ENVIRONMENT}-${ASSUME_ACCOUNT_TYPE}"
  export AWS_PROFILE

  echo "✅ AWS Profile: ${AWS_PROFILE}"

  # 認証確認
  if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS認証に失敗しました | AWS authentication failed" >&2
    echo "Profile: ${AWS_PROFILE}" >&2
    return 1
  fi

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  echo "✅ Account ID: ${ACCOUNT_ID}"
  echo ""

  return 0
fi

# GitHub Actions実行時: AssumeRole実行
echo "ℹ️  GitHub Actions実行モード: AssumeRoleを実行します"
echo "ℹ️  GitHub Actions execution mode: Performing AssumeRole"

# アカウントIDを取得
ASSUME_ACCOUNT_ID=$("${ASSUME_SCRIPT_DIR}/get-account-id.sh" "$ASSUME_ENVIRONMENT" "$ASSUME_ACCOUNT_TYPE")

if [ -z "$ASSUME_ACCOUNT_ID" ]; then
  echo "❌ Error: アカウントIDの取得に失敗しました | Failed to get account ID" >&2
  return 1
fi

# Role ARNを構築
ASSUME_ROLE_ARN="arn:aws:iam::${ASSUME_ACCOUNT_ID}:role/GitHubActionsDeployRole"

# External IDを取得（GitHub Secrets）
if [ -z "${AWS_EXTERNAL_ID:-}" ]; then
  echo "❌ Error: AWS_EXTERNAL_ID 環境変数が設定されていません" >&2
  echo "❌ Error: AWS_EXTERNAL_ID environment variable is not set" >&2
  return 1
fi

# セッション名を構築
SESSION_NAME="github-actions-deploy-${GITHUB_RUN_ID:-unknown}"

echo "Role ARN: ${ASSUME_ROLE_ARN}"
echo "Session Name: ${SESSION_NAME}"
echo ""

# AssumeRole実行（リトライロジック付き）
ASSUME_MAX_RETRIES=3
ASSUME_RETRY_INTERVAL=10

for i in $(seq 1 $ASSUME_MAX_RETRIES); do
  echo "AssumeRole試行 ${i}/${ASSUME_MAX_RETRIES}..."
  echo "AssumeRole attempt ${i}/${ASSUME_MAX_RETRIES}..."

  # AssumeRole実行
  ASSUME_RESULT=$(aws sts assume-role \
    --role-arn "$ASSUME_ROLE_ARN" \
    --role-session-name "$SESSION_NAME" \
    --external-id "$AWS_EXTERNAL_ID" \
    --duration-seconds 3600 \
    --output json 2>&1)

  ASSUME_EXIT_CODE=$?

  if [ $ASSUME_EXIT_CODE -eq 0 ]; then
    # 成功
    echo "✅ AssumeRole成功 | AssumeRole succeeded"

    # 認証情報を環境変数にエクスポート
    export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_RESULT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_RESULT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ASSUME_RESULT" | jq -r '.Credentials.SessionToken')

    # 認証確認
    ASSUMED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✅ Assumed Account ID: ${ASSUMED_ACCOUNT_ID}"
    echo ""

    # アカウントIDが一致するか確認
    if [ "$ASSUMED_ACCOUNT_ID" != "$ASSUME_ACCOUNT_ID" ]; then
      echo "⚠️  Warning: AssumeRoleしたアカウントIDが期待値と異なります" >&2
      echo "⚠️  Warning: Assumed account ID does not match expected value" >&2
      echo "Expected: ${ASSUME_ACCOUNT_ID}" >&2
      echo "Actual: ${ASSUMED_ACCOUNT_ID}" >&2
    fi

    return 0
  fi

  # 失敗
  echo "❌ AssumeRole失敗 (試行 ${i}/${ASSUME_MAX_RETRIES}) | AssumeRole failed (attempt ${i}/${ASSUME_MAX_RETRIES})" >&2
  echo "Error: ${ASSUME_RESULT}" >&2

  # 最後の試行でなければリトライ
  if [ $i -lt $ASSUME_MAX_RETRIES ]; then
    echo "⏳ ${ASSUME_RETRY_INTERVAL}秒後にリトライします... | Retrying in ${ASSUME_RETRY_INTERVAL} seconds..." >&2
    sleep $ASSUME_RETRY_INTERVAL
  fi
done

# すべてのリトライが失敗
echo "❌ Error: AssumeRoleに失敗しました（最大リトライ回数到達）" >&2
echo "❌ Error: AssumeRole failed (maximum retries reached)" >&2
return 1
