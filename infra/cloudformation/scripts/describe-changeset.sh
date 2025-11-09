#!/bin/bash

###############################################################################
# CloudFormation Change Set Details Script
#
# Usage: ./describe-changeset.sh <environment> <layer> <stack-name> <changeset-name>
# Example: ./describe-changeset.sh production 02_network vpc-core-stack changeset-20251107120000
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REGION="ap-northeast-1"
PROJECT_NAME="niigata-kaigo"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[CHANGESET]${NC} $1"
}

# Validate arguments
if [ $# -ne 4 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <environment> <layer> <stack-name> <changeset-name>"
    echo "Example: $0 production 02_network vpc-core-stack changeset-20251107120000"
    exit 1
fi

ENVIRONMENT=$1
LAYER=$2
STACK_NAME_BASE=$3
CHANGESET_NAME=$4

# Construct full stack name
FULL_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${STACK_NAME_BASE}"

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: production, staging"
    exit 1
fi

print_header "==================================================="
print_header "Change Set Details (dry-run)"
print_header "==================================================="
print_info "Stack Name:   $FULL_STACK_NAME"
print_info "Change Set:   $CHANGESET_NAME"
print_info "Environment:  $ENVIRONMENT"
print_info "Layer:        $LAYER"
print_info "Region:       $REGION"
print_header "==================================================="

# Check if change set exists
set +e  # Temporarily disable exit on error
aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION > /dev/null 2>&1

CHANGESET_EXISTS=$?
set -e  # Re-enable exit on error

if [ $CHANGESET_EXISTS -ne 0 ]; then
    print_error "Change Set not found: $CHANGESET_NAME"
    print_info "Available Change Sets:"
    aws cloudformation list-change-sets \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'Summaries[*].[ChangeSetName,Status,CreationTime]' \
        --output table
    exit 1
fi

# Get Change Set status
CHANGESET_STATUS=$(aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Status' \
    --output text)

print_info "Change Set Status: ${CHANGESET_STATUS}"

# If failed, show reason
if [ "$CHANGESET_STATUS" == "FAILED" ]; then
    CHANGESET_STATUS_REASON=$(aws cloudformation describe-change-set \
        --stack-name $FULL_STACK_NAME \
        --change-set-name $CHANGESET_NAME \
        --region $REGION \
        --query 'StatusReason' \
        --output text)

    print_error "Change Set failed: $CHANGESET_STATUS_REASON"

    if [[ "$CHANGESET_STATUS_REASON" == *"didn't contain changes"* ]]; then
        print_warn "No changes detected. Stack is already up to date."
        exit 0
    fi
    exit 1
fi

# Display Change Set summary
print_header ""
print_header "Change Set Summary:"
print_header "==================================================="

aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query '{CreationTime:CreationTime,ExecutionStatus:ExecutionStatus,Status:Status}' \
    --output table

# Display changes
print_header ""
print_header "Changes:"
print_header "==================================================="

aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Changes[*].[Type,ResourceChange.Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType,ResourceChange.Replacement]' \
    --output table

# Display detailed changes (JSON format for full details)
print_header ""
print_header "Detailed Changes (JSON):"
print_header "==================================================="

aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Changes' \
    --output json

# Warning for critical changes
print_header ""
print_header "Critical Change Warnings:"
print_header "==================================================="

# Check for resource replacements
REPLACEMENTS=$(aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Changes[?ResourceChange.Replacement==`True`].ResourceChange.[LogicalResourceId,ResourceType]' \
    --output text)

if [ -n "$REPLACEMENTS" ]; then
    print_warn "The following resources will be REPLACED (recreated):"
    echo "$REPLACEMENTS"
    print_warn "This may cause downtime or data loss!"
else
    print_info "No resource replacements detected."
fi

# Check for deletions
DELETIONS=$(aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Changes[?ResourceChange.Action==`Remove`].ResourceChange.[LogicalResourceId,ResourceType]' \
    --output text)

if [ -n "$DELETIONS" ]; then
    print_warn "The following resources will be DELETED:"
    echo "$DELETIONS"
else
    print_info "No resource deletions detected."
fi

print_header ""
print_header "==================================================="
print_info "This is a dry-run. No changes have been applied."
print_info ""
print_info "To execute this Change Set, run:"
print_info "  ./scripts/execute-changeset.sh $ENVIRONMENT $LAYER $STACK_NAME_BASE $CHANGESET_NAME"
print_info ""
print_info "To delete this Change Set, run:"
print_info "  aws cloudformation delete-change-set --stack-name $FULL_STACK_NAME --change-set-name $CHANGESET_NAME --region $REGION"
print_header "==================================================="
