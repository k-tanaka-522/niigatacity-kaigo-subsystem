#!/bin/bash
# =============================================================================
# deploy-all.sh
#
# Multi-Account Full Stack Deployment Automation
#
# このスクリプトは以下を自動化します：
# 1. S3バケット作成・テンプレートアップロード
# 2. Common Account Network Stack デプロイ
# 3. App Stack パラメータ自動生成
# 4. App Account Network Stack デプロイ
#
# Usage:
#   ./scripts/deploy-all.sh <environment>
#
# Example:
#   ./scripts/deploy-all.sh staging
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

echo "========================================="
echo "Multi-Account Full Stack Deployment"
echo "========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Project: ${PROJECT_NAME}"
echo ""
echo "This script will deploy:"
echo "  1. Common Account Network Stack"
echo "  2. App Account Network Stack (with auto-generated parameters)"
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Deployment cancelled."
  exit 0
fi
echo ""

# =============================================================================
# Phase 1: S3バケット作成・テンプレートアップロード
# =============================================================================
echo "========================================="
echo "Phase 1: S3 Bucket & Template Upload"
echo "========================================="

if [[ ! -f "./scripts/upload-templates.sh" ]]; then
  echo "❌ Error: upload-templates.sh not found"
  exit 1
fi

./scripts/upload-templates.sh ${ENVIRONMENT}

echo ""
echo "✅ Phase 1 Complete: Templates uploaded"
echo ""

# =============================================================================
# Phase 2: Common Account Network Stack
# =============================================================================
echo "========================================="
echo "Phase 2: Common Account Network Stack"
echo "========================================="

COMMON_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-common-network-stack"
COMMON_TEMPLATE="infra/common/cloudformation/stacks/02-network/main.yaml"
COMMON_PARAMS="infra/common/cloudformation/parameters/${ENVIRONMENT}.json"

echo "Creating Change Set for Common Network Stack..."
./scripts/create-changeset.sh \
  ${COMMON_STACK_NAME} \
  ${COMMON_TEMPLATE} \
  ${COMMON_PARAMS} \
  ${ENVIRONMENT}

echo ""

# Change Set名を取得
COMMON_CHANGESET_NAME=$(aws cloudformation list-change-sets \
  --stack-name ${COMMON_STACK_NAME} \
  --query 'Summaries[0].ChangeSetName' \
  --output text)

if [[ -z "$COMMON_CHANGESET_NAME" || "$COMMON_CHANGESET_NAME" == "None" ]]; then
  echo "❌ Error: Failed to create Change Set for Common Network Stack"
  exit 1
fi

echo "Change Set created: ${COMMON_CHANGESET_NAME}"
echo ""

# Change Set内容を表示
echo "Reviewing Change Set..."
./scripts/describe-changeset.sh \
  ${COMMON_STACK_NAME} \
  ${COMMON_CHANGESET_NAME}

echo ""
read -p "Execute Common Network Stack Change Set? (yes/no): " CONFIRM_COMMON
if [[ "$CONFIRM_COMMON" != "yes" ]]; then
  echo "Deployment cancelled. Change Set remains for manual execution."
  exit 0
fi

# Change Setを実行
echo "Executing Common Network Stack..."
printf "yes\n" | ./scripts/execute-changeset.sh \
  ${COMMON_STACK_NAME} \
  ${COMMON_CHANGESET_NAME}

echo ""
echo "✅ Phase 2 Complete: Common Network Stack deployed"
echo ""

# =============================================================================
# Phase 3: パラメータファイル自動生成
# =============================================================================
echo "========================================="
echo "Phase 3: Auto-Generate App Parameters"
echo "========================================="

echo "Waiting for Common Stack to complete..."
aws cloudformation wait stack-update-complete --stack-name ${COMMON_STACK_NAME} || \
  aws cloudformation wait stack-create-complete --stack-name ${COMMON_STACK_NAME}

echo ""
echo "Generating App Stack parameters from Common Stack Outputs..."
./scripts/generate-app-params.sh ${ENVIRONMENT}

echo ""
echo "✅ Phase 3 Complete: App parameters generated"
echo ""

# =============================================================================
# Phase 4: App Account Network Stack
# =============================================================================
echo "========================================="
echo "Phase 4: App Account Network Stack"
echo "========================================="

APP_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app-network-stack"
APP_TEMPLATE="infra/app/cloudformation/stacks/03-network/main.yaml"
APP_PARAMS="infra/app/cloudformation/parameters/${ENVIRONMENT}/03-network-stack-params.json"

echo "Creating Change Set for App Network Stack..."
./scripts/create-changeset.sh \
  ${APP_STACK_NAME} \
  ${APP_TEMPLATE} \
  ${APP_PARAMS} \
  ${ENVIRONMENT}

echo ""

# Change Set名を取得
APP_CHANGESET_NAME=$(aws cloudformation list-change-sets \
  --stack-name ${APP_STACK_NAME} \
  --query 'Summaries[0].ChangeSetName' \
  --output text)

if [[ -z "$APP_CHANGESET_NAME" || "$APP_CHANGESET_NAME" == "None" ]]; then
  echo "❌ Error: Failed to create Change Set for App Network Stack"
  exit 1
fi

echo "Change Set created: ${APP_CHANGESET_NAME}"
echo ""

# Change Set内容を表示
echo "Reviewing Change Set..."
./scripts/describe-changeset.sh \
  ${APP_STACK_NAME} \
  ${APP_CHANGESET_NAME}

echo ""
read -p "Execute App Network Stack Change Set? (yes/no): " CONFIRM_APP
if [[ "$CONFIRM_APP" != "yes" ]]; then
  echo "Deployment cancelled. Change Set remains for manual execution."
  exit 0
fi

# Change Setを実行
echo "Executing App Network Stack..."
printf "yes\n" | ./scripts/execute-changeset.sh \
  ${APP_STACK_NAME} \
  ${APP_CHANGESET_NAME}

echo ""
echo "✅ Phase 4 Complete: App Network Stack deployed"
echo ""

# =============================================================================
# 完了メッセージ
# =============================================================================
echo "========================================="
echo "✅ Full Deployment Complete!"
echo "========================================="
echo ""
echo "Deployed Stacks:"
echo "  1. ${COMMON_STACK_NAME}"
echo "  2. ${APP_STACK_NAME}"
echo ""
echo "Next Steps:"
echo "  - Verify resources in AWS Console"
echo "  - Test connectivity between Common VPC and App VPC"
echo "  - Deploy Security Stack (KMS, Security Groups)"
echo "  - Deploy Database Stack (RDS MySQL)"
echo ""
echo "To check stack status:"
echo "  aws cloudformation describe-stacks --stack-name ${COMMON_STACK_NAME}"
echo "  aws cloudformation describe-stacks --stack-name ${APP_STACK_NAME}"
echo ""
