#!/bin/bash
set -euo pipefail

# ==============================================================================
# CloudFormation Stack Deletion Script
# ==============================================================================
# 使い方:
#   ./scripts/delete-stack.sh staging vpc-core-stack
# ==============================================================================

ENVIRONMENT=${1:-}
STACK_TYPE=${2:-}

if [ -z "$ENVIRONMENT" ] || [ -z "$STACK_TYPE" ]; then
  echo "Usage: $0 <environment> <stack-type>"
  echo "  Example: $0 staging vpc-core-stack"
  echo ""
  echo "Available stack types:"
  echo "  - vpc-core-stack"
  echo "  - kms-stack"
  echo "  - cognito-stack"
  echo "  - rds-mysql-stack"
  echo "  - ecs-alb-stack"
  echo "  - s3-cloudfront-stack"
  echo "  - client-vpn-stack"
  exit 1
fi

PROJECT_NAME="niigata-kaigo"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${STACK_TYPE}"

echo "===================================="
echo "CloudFormation Stack Deletion"
echo "===================================="
echo "Stack Name: ${STACK_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Type: ${STACK_TYPE}"
echo "===================================="
echo ""

# スタックの存在確認
if ! aws cloudformation describe-stacks --stack-name ${STACK_NAME} &>/dev/null; then
  echo "❌ Error: Stack '${STACK_NAME}' does not exist."
  exit 1
fi

# DeletionPolicy確認
echo "⚠️  Deletion Policy:"
echo "  - RDS: Snapshot will be created before deletion (DeletionPolicy: Snapshot)"
echo "  - S3: Buckets will be retained (DeletionPolicy: Retain)"
echo "  - Other resources: Will be deleted permanently"
echo ""

# 依存関係の警告
echo "⚠️  Dependency Warning:"
echo "  - Ensure dependent stacks are deleted first (reverse order of creation)"
echo "  - Example: ECS → RDS → VPC"
echo ""

# GCAS準拠: 削除理由の記録
read -p "Deletion reason (for audit trail): " DELETION_REASON

# 最終確認
read -p "Are you sure you want to delete '${STACK_NAME}'? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Deletion cancelled."
  exit 0
fi

# 削除実行
echo "Deleting stack: ${STACK_NAME}"
echo "Deletion reason: ${DELETION_REASON}"

aws cloudformation delete-stack --stack-name ${STACK_NAME}

echo "Waiting for stack deletion..."
aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} || {
  echo "❌ Error: Stack deletion failed or timed out."
  echo "Check status: aws cloudformation describe-stacks --stack-name ${STACK_NAME}"
  exit 1
}

echo "✅ Stack deleted successfully: ${STACK_NAME}"

# GCAS準拠: 削除ログをS3に保存（オプション）
# echo "${DELETION_REASON}" | aws s3 cp - s3://${PROJECT_NAME}-audit-logs/deletion-logs/${STACK_NAME}-$(date +%Y%m%d-%H%M%S).txt
