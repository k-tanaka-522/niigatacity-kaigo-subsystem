#!/bin/bash

##############################################################################
# Multi-Account CloudFormation Rollback Script
#
# Usage:
#   ./scripts/rollback-multi-account.sh <account> <environment>
#
# Arguments:
#   account:     'common' or 'app'
#   environment: 'dev' | 'staging' | 'production'
#
# Examples:
#   # Rollback common account in dev
#   ./scripts/rollback-multi-account.sh common dev
#
#   # Rollback app account in staging
#   ./scripts/rollback-multi-account.sh app staging
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
    error "Usage: $0 <account> <environment>"
    error "  account:     'common' or 'app'"
    error "  environment: 'dev' | 'staging' | 'production'"
    exit 1
fi

ACCOUNT=$1
ENVIRONMENT=$2

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

# Set stack name based on account type
if [ "$ACCOUNT" == "common" ]; then
    STACK_NAME="niigata-kaigo-${ENVIRONMENT}-common-network-stack"
elif [ "$ACCOUNT" == "app" ]; then
    STACK_NAME="niigata-kaigo-${ENVIRONMENT}-app-network-stack"
fi

info "=================================================="
info "Multi-Account CloudFormation Rollback"
info "=================================================="
info "Account:     $ACCOUNT"
info "Environment: $ENVIRONMENT"
info "Stack Name:  $STACK_NAME"
info "=================================================="

# Step 1: Check if stack exists
set +e
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region ap-northeast-1 > /dev/null 2>&1
STACK_EXISTS=$?
set -e

if [ $STACK_EXISTS -ne 0 ]; then
    error "Stack does not exist: $STACK_NAME"
    exit 1
fi

# Step 2: Get current stack status
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region ap-northeast-1 \
    --query 'Stacks[0].StackStatus' \
    --output text)

info "Current Stack Status: $STACK_STATUS"

# Step 3: Check if rollback is possible
if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]]; then
    error "Stack is in ROLLBACK_COMPLETE state. Cannot rollback further."
    error "Please delete and recreate the stack."
    exit 1
fi

if [[ "$STACK_STATUS" != "UPDATE_ROLLBACK_COMPLETE" ]] && [[ "$STACK_STATUS" != "UPDATE_IN_PROGRESS" ]] && [[ "$STACK_STATUS" != "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" ]] && [[ "$STACK_STATUS" != "UPDATE_COMPLETE" ]] && [[ "$STACK_STATUS" != "UPDATE_FAILED" ]]; then
    warning "Stack is not in a state that allows rollback."
    warning "Current status: $STACK_STATUS"
    exit 1
fi

# Step 4: Confirm rollback
warning "This will rollback the stack to the previous version."
warning "Are you sure you want to continue? (yes/no)"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    info "Rollback cancelled."
    exit 0
fi

# Step 5: Cancel update (if in progress)
if [[ "$STACK_STATUS" == "UPDATE_IN_PROGRESS" ]] || [[ "$STACK_STATUS" == "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" ]]; then
    info "Stack update is in progress. Cancelling update..."

    aws cloudformation cancel-update-stack \
        --stack-name "$STACK_NAME" \
        --region ap-northeast-1

    success "Update cancellation initiated."

    info "Waiting for rollback to complete..."

    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region ap-northeast-1 || true

    success "Rollback completed."
else
    # Step 6: Perform rollback
    info "Initiating rollback..."

    aws cloudformation rollback-stack \
        --stack-name "$STACK_NAME" \
        --region ap-northeast-1 || {
        error "Rollback initiation failed. The stack may not support rollback."
        exit 1
    }

    success "Rollback initiated."

    info "Waiting for rollback to complete..."

    aws cloudformation wait stack-rollback-complete \
        --stack-name "$STACK_NAME" \
        --region ap-northeast-1 || true

    success "Rollback completed."
fi

# Step 7: Show stack status
info "=================================================="
info "Final Stack Status:"
info "=================================================="

aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region ap-northeast-1 \
    --query 'Stacks[0].[StackName,StackStatus,StackStatusReason]' \
    --output table

success "Rollback script completed."
