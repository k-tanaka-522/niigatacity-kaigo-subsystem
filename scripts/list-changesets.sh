#!/bin/bash

# list-changesets.sh - CloudFormation Change Set一覧表示スクリプト
# Usage: ./list-changesets.sh <stack-name> <environment>

set -e

STACK_NAME=$1
ENVIRONMENT=$2

if [ -z "$STACK_NAME" ] || [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 <stack-name> <environment>"
  echo "Example: $0 niigata-kaigo-staging-common-network-stack staging"
  exit 1
fi

# AWS Profile設定
get_aws_profile() {
  local environment=$1
  case "${environment}" in
    production|staging|dev|*)
      echo "default"
      ;;
  esac
}

AWS_PROFILE=$(get_aws_profile "${ENVIRONMENT}")
REGION="ap-northeast-1"

echo "=========================================="
echo "Change Sets for Stack: ${STACK_NAME}"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "AWS Profile: ${AWS_PROFILE}"
echo "Region:      ${REGION}"
echo "=========================================="

# Change Set一覧取得
aws cloudformation list-change-sets \
  --stack-name "${STACK_NAME}" \
  --profile "${AWS_PROFILE}" \
  --region "${REGION}" \
  --query 'Summaries[*].{Name:ChangeSetName,Status:Status,ExecutionStatus:ExecutionStatus,CreatedTime:CreationTime}' \
  --output table 2>&1

if [ $? -ne 0 ]; then
  echo "✗ Stack not found or no Change Sets exist"
  exit 1
fi
