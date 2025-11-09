#!/bin/bash

###############################################################################
# CloudFormation Stack Rollback Script
#
# Usage: ./rollback.sh <environment> <layer> <stack-name>
# Example: ./rollback.sh production 02_network vpc-core-stack
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate arguments
if [ $# -ne 3 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <environment> <layer> <stack-name>"
    echo "Example: $0 production 02_network vpc-core-stack"
    exit 1
fi

ENVIRONMENT=$1
LAYER=$2
STACK_NAME_BASE=$3

# Construct full stack name
FULL_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${STACK_NAME_BASE}"

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: production, staging"
    exit 1
fi

print_warn "==================================================="
print_warn "CloudFormation Stack Rollback"
print_warn "==================================================="
print_warn "Environment:  $ENVIRONMENT"
print_warn "Layer:        $LAYER"
print_warn "Stack Name:   $FULL_STACK_NAME"
print_warn "Region:       $REGION"
print_warn "==================================================="

# Check if stack exists
set +e  # Temporarily disable exit on error
aws cloudformation describe-stacks \
    --stack-name $FULL_STACK_NAME \
    --region $REGION > /dev/null 2>&1

STACK_EXISTS=$?
set -e  # Re-enable exit on error

if [ $STACK_EXISTS -ne 0 ]; then
    print_error "Stack not found: $FULL_STACK_NAME"
    exit 1
fi

# Get current stack status
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $FULL_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text)

print_info "Current Stack Status: $STACK_STATUS"

# Check if stack is in a rollback-able state
case "$STACK_STATUS" in
    "UPDATE_FAILED"|"UPDATE_ROLLBACK_FAILED"|"UPDATE_IN_PROGRESS")
        print_info "Stack can be rolled back."
        ;;
    "UPDATE_COMPLETE"|"CREATE_COMPLETE")
        print_warn "Stack is in a stable state. No rollback needed."
        print_warn "If you want to revert to a previous version, use Change Sets with the old template."
        exit 0
        ;;
    "ROLLBACK_IN_PROGRESS"|"UPDATE_ROLLBACK_IN_PROGRESS")
        print_warn "Stack is already rolling back."
        exit 0
        ;;
    "DELETE_IN_PROGRESS"|"DELETE_COMPLETE")
        print_error "Stack is being deleted or already deleted."
        exit 1
        ;;
    *)
        print_warn "Stack status: $STACK_STATUS"
        print_warn "Rollback may not be applicable for this status."
        ;;
esac

# Show recent stack events
print_info ""
print_info "Recent Stack Events:"
print_info "==================================================="

aws cloudformation describe-stack-events \
    --stack-name $FULL_STACK_NAME \
    --region $REGION \
    --max-items 10 \
    --query 'StackEvents[*].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
    --output table

# Confirmation prompt
print_warn ""
print_warn "⚠️  WARNING: This will rollback the stack to its previous stable state!"
print_warn "⚠️  Any changes made in the failed update will be lost!"
print_warn ""

if [ "$ENVIRONMENT" == "production" ]; then
    read -p "Do you want to rollback this stack in PRODUCTION? Type 'rollback-production' to confirm: " CONFIRMATION

    if [ "$CONFIRMATION" != "rollback-production" ]; then
        print_warn "Rollback cancelled by user"
        exit 0
    fi
else
    read -p "Do you want to rollback this stack? Type 'yes' to confirm: " CONFIRMATION

    if [ "$CONFIRMATION" != "yes" ]; then
        print_warn "Rollback cancelled by user"
        exit 0
    fi
fi

# Execute rollback based on stack status
print_info ""
print_info "Initiating rollback..."

if [ "$STACK_STATUS" == "UPDATE_ROLLBACK_FAILED" ]; then
    # For UPDATE_ROLLBACK_FAILED, use continue-update-rollback
    print_info "Using continue-update-rollback for failed rollback state..."

    aws cloudformation continue-update-rollback \
        --stack-name $FULL_STACK_NAME \
        --region $REGION

    if [ $? -ne 0 ]; then
        print_error "Failed to continue rollback"
        exit 1
    fi

else
    # For UPDATE_FAILED or UPDATE_IN_PROGRESS, cancel update to trigger rollback
    print_info "Canceling stack update to trigger rollback..."

    aws cloudformation cancel-update-stack \
        --stack-name $FULL_STACK_NAME \
        --region $REGION

    if [ $? -ne 0 ]; then
        print_error "Failed to cancel stack update"
        exit 1
    fi
fi

print_info "${GREEN}Rollback initiated successfully${NC}"
print_info ""
print_info "Waiting for rollback to complete..."
print_info "This may take several minutes..."

# Wait for rollback to complete
aws cloudformation wait stack-update-rollback-complete \
    --stack-name $FULL_STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    print_info "${GREEN}Rollback completed successfully!${NC}"
    print_info "Stack Name: $FULL_STACK_NAME"

    # Display stack status
    print_info "==================================================="
    print_info "Stack Status:"
    print_info "==================================================="

    aws cloudformation describe-stacks \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].[StackName,StackStatus,LastUpdatedTime]' \
        --output table

    print_info ""
    print_info "Stack has been rolled back to its previous stable state."

else
    print_error "Rollback failed or timed out"

    # Display failure details
    print_error "==================================================="
    print_error "Recent Events:"
    print_error "==================================================="

    aws cloudformation describe-stack-events \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --max-items 20 \
        --query 'StackEvents[*].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
        --output table

    print_error ""
    print_error "Please check the CloudFormation console for more details:"
    print_error "https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks/stackinfo?stackId=$FULL_STACK_NAME"

    exit 1
fi

print_info "==================================================="
print_info "${GREEN}Rollback operation completed!${NC}"
print_info "==================================================="
