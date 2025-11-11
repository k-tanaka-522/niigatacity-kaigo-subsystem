#!/bin/bash

#######################################
# CloudFormation Deploy All Stacks Script
# Description: Deploys all CloudFormation stacks in dependency order
# Usage: ./scripts/deploy-all.sh <account-type> <environment>
# Example: ./scripts/deploy-all.sh common staging
#          ./scripts/deploy-all.sh app dev
#######################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arguments
ACCOUNT_TYPE=$1
ENVIRONMENT=$2
REGION="ap-northeast-1"

# Function to show usage
usage() {
  echo "Usage: $0 <account-type> <environment>"
  echo ""
  echo "Arguments:"
  echo "  account-type: 'common' or 'app'"
  echo "  environment:  'dev', 'staging', or 'production'"
  echo ""
  echo "Examples:"
  echo "  $0 common staging"
  echo "  $0 app dev"
  exit 1
}

# Validate arguments
if [ -z "${ACCOUNT_TYPE}" ] || [ -z "${ENVIRONMENT}" ]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  usage
fi

if [ "${ACCOUNT_TYPE}" != "common" ] && [ "${ACCOUNT_TYPE}" != "app" ]; then
  echo -e "${RED}Error: account-type must be 'common' or 'app'${NC}"
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
echo "CloudFormation Deploy All Stacks"
echo "========================================"
echo "Account Type: ${ACCOUNT_TYPE}"
echo "Environment:  ${ENVIRONMENT}"
echo "AWS Profile:  ${AWS_PROFILE}"
echo "Account ID:   $(aws sts get-caller-identity --query Account --output text)"
echo "Region:       ${REGION}"
echo ""

# Function to deploy a stack using Change Sets
deploy_stack() {
  local stack_name=$1
  local template=$2
  local parameters=$3
  local capabilities=$4

  echo ""
  echo "========================================"
  echo "Deploying: ${stack_name}"
  echo "========================================"
  echo "Template:    ${template}"
  echo "Parameters:  ${parameters}"
  echo "Capabilities: ${capabilities}"
  echo ""

  # Check if stack exists
  set +e
  aws cloudformation describe-stacks \
    --stack-name "${stack_name}" \
    --region "${REGION}" \
    --output text > /dev/null 2>&1
  STACK_EXISTS=$?
  set -e

  if [ $STACK_EXISTS -eq 0 ]; then
    CHANGE_SET_TYPE="UPDATE"
    echo "Stack exists. Creating UPDATE Change Set..."
  else
    CHANGE_SET_TYPE="CREATE"
    echo "Stack does not exist. Creating CREATE Change Set..."
  fi

  # Create Change Set
  CHANGESET_NAME="${stack_name}-changeset-$(date +%Y%m%d-%H%M%S)"

  echo "Change Set Name: ${CHANGESET_NAME}"
  echo ""

  aws cloudformation create-change-set \
    --stack-name "${stack_name}" \
    --change-set-name "${CHANGESET_NAME}" \
    --template-body file://"${template}" \
    --parameters file://"${parameters}" \
    --capabilities ${capabilities} \
    --change-set-type "${CHANGE_SET_TYPE}" \
    --region "${REGION}" \
    --output text > /dev/null

  echo "Waiting for Change Set to be created..."
  aws cloudformation wait change-set-create-complete \
    --stack-name "${stack_name}" \
    --change-set-name "${CHANGESET_NAME}" \
    --region "${REGION}"

  echo -e "${GREEN}✓ Change Set created${NC}"
  echo ""

  # Display Change Set
  echo "Change Set Details:"
  echo "----------------------------------------"
  aws cloudformation describe-change-set \
    --stack-name "${stack_name}" \
    --change-set-name "${CHANGESET_NAME}" \
    --region "${REGION}" \
    --query '{Status:Status,ExecutionStatus:ExecutionStatus,Changes:Changes[*].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,ResourceType:ResourceChange.ResourceType}}' \
    --output table

  echo ""
  echo -e "${YELLOW}⚠️  Review the Change Set above${NC}"
  echo -n "Do you want to execute this Change Set? (yes/no): "
  read -r CONFIRMATION

  if [ "${CONFIRMATION}" != "yes" ]; then
    echo "Skipping stack deployment."
    echo "Deleting Change Set..."
    aws cloudformation delete-change-set \
      --stack-name "${stack_name}" \
      --change-set-name "${CHANGESET_NAME}" \
      --region "${REGION}"
    return 1
  fi

  echo ""
  echo "Executing Change Set..."
  aws cloudformation execute-change-set \
    --stack-name "${stack_name}" \
    --change-set-name "${CHANGESET_NAME}" \
    --region "${REGION}"

  echo "Waiting for stack operation to complete..."
  echo "(This may take several minutes)"

  if [ "${CHANGE_SET_TYPE}" == "CREATE" ]; then
    aws cloudformation wait stack-create-complete \
      --stack-name "${stack_name}" \
      --region "${REGION}"
  else
    aws cloudformation wait stack-update-complete \
      --stack-name "${stack_name}" \
      --region "${REGION}"
  fi

  echo -e "${GREEN}✓ Stack deployed successfully!${NC}"
  echo ""

  # Display Outputs
  echo "Stack Outputs:"
  echo "----------------------------------------"
  aws cloudformation describe-stacks \
    --stack-name "${stack_name}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table || echo "No outputs"

  echo ""
}

# Deploy stacks based on account type
if [ "${ACCOUNT_TYPE}" == "common" ]; then
  echo "Deploying Common Account Stacks (${ENVIRONMENT} environment)"
  echo ""

  # Stack 1: Network Stack (if exists)
  if [ -f "infra/common/cloudformation/stacks/02-network/main.yaml" ]; then
    deploy_stack \
      "niigata-kaigo-${ENVIRONMENT}-common-network-stack" \
      "infra/common/cloudformation/stacks/02-network/main.yaml" \
      "infra/common/cloudformation/parameters/${ENVIRONMENT}/02-network-stack-params.json" \
      "CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND" || {
        echo -e "${RED}✗ Network Stack deployment failed${NC}"
        exit 1
      }
  fi

  # Stack 2: Security Monitoring Stack
  if [ -f "infra/common/cloudformation/stacks/03-security-monitoring/main.yaml" ]; then
    deploy_stack \
      "niigata-kaigo-${ENVIRONMENT}-security-monitoring-stack" \
      "infra/common/cloudformation/stacks/03-security-monitoring/main.yaml" \
      "infra/common/cloudformation/parameters/${ENVIRONMENT}/03-security-monitoring-stack-params.json" \
      "CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND" || {
        echo -e "${RED}✗ Security Monitoring Stack deployment failed${NC}"
        exit 1
      }
  fi

elif [ "${ACCOUNT_TYPE}" == "app" ]; then
  echo "Deploying App Account Stacks (${ENVIRONMENT} environment)"
  echo ""

  # Stack order based on dependencies (from design document)
  STACKS=(
    "03-network"
    "04-security"
    "05-database"
    "06-compute"
    "07-storage"
    "08-auth"
    "09-monitoring"
  )

  for stack_num in "${STACKS[@]}"; do
    STACK_DIR="infra/app/cloudformation/stacks/${stack_num}"
    STACK_NAME="niigata-kaigo-${ENVIRONMENT}-app-${stack_num##*-}-stack"
    TEMPLATE="${STACK_DIR}/main.yaml"
    PARAMETERS="infra/app/cloudformation/parameters/${ENVIRONMENT}/${stack_num}-stack-params.json"

    if [ -f "${TEMPLATE}" ] && [ -f "${PARAMETERS}" ]; then
      deploy_stack \
        "${STACK_NAME}" \
        "${TEMPLATE}" \
        "${PARAMETERS}" \
        "CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND" || {
          echo -e "${RED}✗ Stack deployment failed: ${STACK_NAME}${NC}"
          echo ""
          echo "Rollback Options:"
          echo "1. Fix the issue and re-run this script"
          echo "2. Delete failed stack: ./scripts/delete-stack.sh ${STACK_NAME} ${ENVIRONMENT}"
          echo "3. Check CloudFormation console for error details"
          exit 1
        }
    else
      echo -e "${YELLOW}⚠️  Skipping ${stack_num}: template or parameters not found${NC}"
    fi
  done
fi

echo ""
echo "========================================"
echo -e "${GREEN}✓ All stacks deployed successfully!${NC}"
echo "========================================"
echo "Account Type: ${ACCOUNT_TYPE}"
echo "Environment:  ${ENVIRONMENT}"
echo "Completed At: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
