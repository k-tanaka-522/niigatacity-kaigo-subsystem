#!/bin/bash

#######################################
# CloudFormation Stack Deletion Script
# Description: Deletes a CloudFormation stack with confirmation
# Usage: ./scripts/delete-stack.sh <stack-name> <environment>
# Example: ./scripts/delete-stack.sh niigata-kaigo-dev-vpc-stack dev
#######################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Arguments
STACK_NAME=$1
ENVIRONMENT=$2
REGION="ap-northeast-1"

# Function to show usage
usage() {
  echo "Usage: $0 <stack-name> <environment>"
  echo ""
  echo "Arguments:"
  echo "  stack-name:   CloudFormation stack name"
  echo "  environment:  'dev', 'staging', or 'production'"
  echo ""
  echo "Examples:"
  echo "  $0 niigata-kaigo-dev-vpc-stack dev"
  echo "  $0 niigata-kaigo-staging-security-monitoring-stack staging"
  exit 1
}

# Validate arguments
if [ -z "${STACK_NAME}" ] || [ -z "${ENVIRONMENT}" ]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  usage
fi

if [ "${ENVIRONMENT}" != "dev" ] && [ "${ENVIRONMENT}" != "staging" ] && [ "${ENVIRONMENT}" != "production" ]; then
  echo -e "${RED}Error: environment must be 'dev', 'staging', or 'production'${NC}"
  usage
fi

# Get AWS Profile based on environment
get_aws_profile() {
  local environment=$1
  case "${environment}" in
    production)
      echo "niigata-kaigo-prod"
      ;;
    staging)
      echo "niigata-kaigo-stg"
      ;;
    dev)
      echo "default"
      ;;
    *)
      echo "default"
      ;;
  esac
}

AWS_PROFILE=$(get_aws_profile "${ENVIRONMENT}")
export AWS_PROFILE

echo "========================================"
echo "CloudFormation Stack Deletion"
echo "========================================"
echo "Stack Name:   ${STACK_NAME}"
echo "Environment:  ${ENVIRONMENT}"
echo "AWS Profile:  ${AWS_PROFILE}"
echo "Region:       ${REGION}"
echo ""

# Check if stack exists
echo "Checking if stack exists..."
if ! aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --output text > /dev/null 2>&1; then
  echo -e "${RED}Error: Stack '${STACK_NAME}' does not exist${NC}"
  exit 1
fi

# Get stack details
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query 'Stacks[0].StackStatus' \
  --output text)

echo -e "${GREEN}✓ Stack exists${NC}"
echo "Current Status: ${STACK_STATUS}"
echo ""

# Show stack resources
echo "Stack Resources:"
echo "----------------------------------------"
aws cloudformation list-stack-resources \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
  --output table

echo ""
echo -e "${YELLOW}⚠️  WARNING: This action will DELETE the stack and all its resources!${NC}"
echo -e "${YELLOW}⚠️  This action CANNOT be undone!${NC}"
echo ""
echo -n "Are you sure you want to delete this stack? (yes/no): "
read -r CONFIRMATION

if [ "${CONFIRMATION}" != "yes" ]; then
  echo "Deletion cancelled."
  exit 0
fi

echo ""
echo -n "Type the stack name to confirm deletion: "
read -r CONFIRMATION_NAME

if [ "${CONFIRMATION_NAME}" != "${STACK_NAME}" ]; then
  echo -e "${RED}Error: Stack name does not match. Deletion cancelled.${NC}"
  exit 1
fi

echo ""
echo "Deleting stack..."
echo "----------------------------------------"

aws cloudformation delete-stack \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}"

echo ""
echo "Waiting for stack deletion to complete..."
echo "(This may take several minutes)"
echo ""

# Wait for deletion with timeout
timeout 600 aws cloudformation wait stack-delete-complete \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "========================================"
  echo -e "${GREEN}✓ Stack deleted successfully!${NC}"
  echo "========================================"
  echo "Stack Name: ${STACK_NAME}"
  echo "Deleted At: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
elif [ $EXIT_CODE -eq 124 ]; then
  echo ""
  echo "========================================"
  echo -e "${YELLOW}⚠️  Stack deletion timed out after 600 seconds${NC}"
  echo "========================================"
  echo "The stack may still be deleting. Check the AWS Console for status."
  echo ""
else
  echo ""
  echo "========================================"
  echo -e "${RED}✗ Stack deletion failed${NC}"
  echo "========================================"
  echo ""
  echo "Checking stack status..."
  STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>&1 || echo "STACK_NOT_FOUND")

  if [ "${STACK_STATUS}" == "DELETE_FAILED" ]; then
    echo -e "${RED}Status: DELETE_FAILED${NC}"
    echo ""
    echo "Failed Resources:"
    echo "----------------------------------------"
    aws cloudformation list-stack-resources \
      --stack-name "${STACK_NAME}" \
      --region "${REGION}" \
      --query 'StackResourceSummaries[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceType,ResourceStatusReason]' \
      --output table
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if resources have dependencies that need to be deleted first"
    echo "2. Check if resources are protected from deletion"
    echo "3. Delete problematic resources manually, then retry stack deletion"
    echo ""
  fi
  exit 1
fi
