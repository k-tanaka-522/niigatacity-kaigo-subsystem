#!/bin/bash

##############################################################################
# Multi-Account CloudFormation Deploy Script
#
# Usage:
#   ./scripts/deploy-multi-account.sh <account> <environment> [--execute]
#
# Arguments:
#   account:     'common' or 'app'
#   environment: 'dev' | 'staging' | 'production'
#   --execute:   Execute change set (optional, default is dry-run only)
#
# Examples:
#   # Dry-run for common account in dev
#   ./scripts/deploy-multi-account.sh common dev
#
#   # Execute for common account in dev
#   ./scripts/deploy-multi-account.sh common dev --execute
#
#   # Dry-run for app account in staging
#   ./scripts/deploy-multi-account.sh app staging
#
##############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
if [ $# -lt 2 ]; then
    error "Usage: $0 <account> <environment> [--execute]"
    error "  account:     'common' or 'app'"
    error "  environment: 'dev' | 'staging' | 'production'"
    error "  --execute:   Execute change set (optional)"
    exit 1
fi

ACCOUNT=$1
ENVIRONMENT=$2
EXECUTE_CHANGESET=false

if [ $# -eq 3 ] && [ "$3" == "--execute" ]; then
    EXECUTE_CHANGESET=true
fi

# Validate account
if [ "$ACCOUNT" != "common" ] && [ "$ACCOUNT" != "app" ]; then
    error "Invalid account: $ACCOUNT. Must be 'common' or 'app'"
    exit 1
fi

# Validate environment
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    error "Invalid environment: $ENVIRONMENT. Must be 'dev', 'staging', or 'production'"
    exit 1
fi

# Set account directory based on account type
if [ "$ACCOUNT" == "common" ]; then
    ACCOUNT_DIR="共通アカウント"
    STACK_NAME="niigata-kaigo-${ENVIRONMENT}-common-network-stack"
    MAIN_TEMPLATE="infra/${ACCOUNT_DIR}/cloudformation/stacks/02-network/main.yaml"
elif [ "$ACCOUNT" == "app" ]; then
    ACCOUNT_DIR="appアカウント"
    STACK_NAME="niigata-kaigo-${ENVIRONMENT}-app-network-stack"
    MAIN_TEMPLATE="infra/${ACCOUNT_DIR}/cloudformation/stacks/03-network/main.yaml"
fi

PARAMETERS_FILE="infra/${ACCOUNT_DIR}/cloudformation/parameters/${ENVIRONMENT}.json"
CHANGE_SET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

info "=================================================="
info "Multi-Account CloudFormation Deployment"
info "=================================================="
info "Account:     $ACCOUNT ($ACCOUNT_DIR)"
info "Environment: $ENVIRONMENT"
info "Stack Name:  $STACK_NAME"
info "Template:    $MAIN_TEMPLATE"
info "Parameters:  $PARAMETERS_FILE"
info "Change Set:  $CHANGE_SET_NAME"
info "Execute:     $EXECUTE_CHANGESET"
info "=================================================="

# Check if files exist
if [ ! -f "$MAIN_TEMPLATE" ]; then
    error "Template file not found: $MAIN_TEMPLATE"
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Step 1: Create Change Set
info "Creating Change Set..."

CHANGE_SET_TYPE="UPDATE"

# Check if stack exists
set +e
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region ap-northeast-1 > /dev/null 2>&1
STACK_EXISTS=$?
set -e

if [ $STACK_EXISTS -ne 0 ]; then
    info "Stack does not exist. Creating new stack."
    CHANGE_SET_TYPE="CREATE"
fi

aws cloudformation create-change-set \
    --stack-name "$STACK_NAME" \
    --template-body "file://$MAIN_TEMPLATE" \
    --parameters "file://$PARAMETERS_FILE" \
    --change-set-name "$CHANGE_SET_NAME" \
    --change-set-type "$CHANGE_SET_TYPE" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region ap-northeast-1

success "Change Set created: $CHANGE_SET_NAME"

# Step 2: Wait for Change Set creation
info "Waiting for Change Set creation..."

aws cloudformation wait change-set-create-complete \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGE_SET_NAME" \
    --region ap-northeast-1 || {

    # Check if the failure is due to no changes
    CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME" \
        --region ap-northeast-1 \
        --query 'Status' \
        --output text)

    CHANGE_SET_STATUS_REASON=$(aws cloudformation describe-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME" \
        --region ap-northeast-1 \
        --query 'StatusReason' \
        --output text)

    if [[ "$CHANGE_SET_STATUS_REASON" == *"didn't contain changes"* ]]; then
        warning "No changes detected. Deleting Change Set."
        aws cloudformation delete-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME" \
            --region ap-northeast-1
        exit 0
    else
        error "Change Set creation failed: $CHANGE_SET_STATUS_REASON"
        exit 1
    fi
}

success "Change Set creation completed."

# Step 3: Describe Change Set (dry-run review)
info "=================================================="
info "Change Set Details (DRY-RUN REVIEW):"
info "=================================================="

aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGE_SET_NAME" \
    --region ap-northeast-1 \
    --query 'Changes[*].[Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType,ResourceChange.Replacement]' \
    --output table

info "=================================================="

# Step 4: Execute Change Set (if --execute flag is provided)
if [ "$EXECUTE_CHANGESET" == true ]; then
    warning "Executing Change Set in 5 seconds... (Press Ctrl+C to cancel)"
    sleep 5

    info "Executing Change Set..."

    aws cloudformation execute-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME" \
        --region ap-northeast-1

    success "Change Set execution started."

    info "Waiting for stack operation to complete..."

    if [ "$CHANGE_SET_TYPE" == "CREATE" ]; then
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region ap-northeast-1
    else
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME" \
            --region ap-northeast-1
    fi

    success "Stack operation completed successfully!"

    # Show stack outputs
    info "=================================================="
    info "Stack Outputs:"
    info "=================================================="

    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region ap-northeast-1 \
        --query 'Stacks[0].Outputs' \
        --output table

else
    warning "Dry-run mode. Change Set created but not executed."
    warning "To execute, run:"
    warning "  ./scripts/deploy-multi-account.sh $ACCOUNT $ENVIRONMENT --execute"
    warning ""
    warning "To delete the Change Set without executing:"
    warning "  aws cloudformation delete-change-set --stack-name $STACK_NAME --change-set-name $CHANGE_SET_NAME --region ap-northeast-1"
fi

success "Deployment script completed."
