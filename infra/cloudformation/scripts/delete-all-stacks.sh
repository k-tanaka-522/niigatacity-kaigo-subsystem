#!/bin/bash
set -euo pipefail

# ==============================================================================
# CloudFormation All Stacks Deletion Script (Reverse Order)
# ==============================================================================
# 使い方:
#   ./scripts/delete-all-stacks.sh staging
# ==============================================================================

ENVIRONMENT=${1:-}

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 <environment>"
  echo "  Example: $0 staging"
  exit 1
fi

PROJECT_NAME="niigata-kaigo"

echo "===================================="
echo "CloudFormation All Stacks Deletion"
echo "===================================="
echo "Environment: ${ENVIRONMENT}"
echo "===================================="
echo ""

echo "⚠️  WARNING: This will delete ALL stacks in the following order:"
echo "  1. Client VPN Stack"
echo "  2. Monitoring Stack"
echo "  3. S3 + CloudFront Stack"
echo "  4. ECS + ALB Stack"
echo "  5. ECR Stack"
echo "  6. RDS Stack"
echo "  7. Cognito Stack"
echo "  8. KMS Stack"
echo "  9. VPC Core Stack"
echo ""

read -p "Deletion reason (for audit trail): " DELETION_REASON
read -p "Are you sure you want to delete ALL stacks in ${ENVIRONMENT}? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Deletion cancelled."
  exit 0
fi

# スタック削除（逆順）
STACKS=(
  "client-vpn-stack"
  "monitoring-stack"
  "s3-cloudfront-stack"
  "ecs-alb-stack"
  "ecr-stack"
  "rds-mysql-stack"
  "cognito-stack"
  "kms-stack"
  "vpc-core-stack"
)

for STACK_TYPE in "${STACKS[@]}"; do
  STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${STACK_TYPE}"

  echo ""
  echo "===================================="
  echo "Deleting: ${STACK_NAME}"
  echo "===================================="

  # スタックの存在確認
  if ! aws cloudformation describe-stacks --stack-name ${STACK_NAME} &>/dev/null; then
    echo "⚠️  Skip: Stack '${STACK_NAME}' does not exist."
    continue
  fi

  # 削除実行
  echo "Reason: ${DELETION_REASON}"
  aws cloudformation delete-stack --stack-name ${STACK_NAME}

  echo "Waiting for stack deletion..."
  aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} || {
    echo "❌ Error: Stack deletion failed or timed out."
    echo "Check status: aws cloudformation describe-stacks --stack-name ${STACK_NAME}"
    exit 1
  }

  echo "✅ Stack deleted: ${STACK_NAME}"
done

echo ""
echo "✅ All stacks deleted successfully."
