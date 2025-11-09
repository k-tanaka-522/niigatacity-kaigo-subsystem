#!/bin/bash

###############################################################################
# CloudFormation Change Set Execution Script
#
# Usage: ./execute-changeset.sh <environment> <layer> <stack-name> <changeset-name>
# Example: ./execute-changeset.sh production 02_network vpc-core-stack changeset-20251107120000
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

print_info "==================================================="
print_info "CloudFormation Change Set Execution"
print_info "==================================================="
print_info "Environment:  $ENVIRONMENT"
print_info "Layer:        $LAYER"
print_info "Stack Name:   $FULL_STACK_NAME"
print_info "Change Set:   $CHANGESET_NAME"
print_info "Region:       $REGION"
print_info "==================================================="

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
    exit 1
fi

# Get Change Set status
CHANGESET_STATUS=$(aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Status' \
    --output text)

# Get Execution Status
EXECUTION_STATUS=$(aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'ExecutionStatus' \
    --output text)

print_info "Change Set Status: $CHANGESET_STATUS"
print_info "Execution Status: $EXECUTION_STATUS"

# Check if Change Set can be executed
if [ "$CHANGESET_STATUS" != "CREATE_COMPLETE" ]; then
    print_error "Change Set is not ready to execute. Status: $CHANGESET_STATUS"
    exit 1
fi

if [ "$EXECUTION_STATUS" != "AVAILABLE" ]; then
    print_error "Change Set is not available for execution. Execution Status: $EXECUTION_STATUS"
    exit 1
fi

# Show Change Set summary before execution
print_info ""
print_info "Change Set will apply the following changes:"
print_info "==================================================="

aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION \
    --query 'Changes[*].[ResourceChange.Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType]' \
    --output table

# Production environment requires manual confirmation
if [ "$ENVIRONMENT" == "production" ]; then
    print_warn ""
    print_warn "⚠️  WARNING: You are about to execute changes in PRODUCTION environment!"
    print_warn ""
    read -p "Do you want to execute this Change Set? Type 'yes' to confirm: " CONFIRMATION

    if [ "$CONFIRMATION" != "yes" ]; then
        print_warn "Execution cancelled by user"
        exit 0
    fi
fi

# Execute Change Set
print_info ""
print_info "Executing Change Set..."

aws cloudformation execute-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGESET_NAME \
    --region $REGION

if [ $? -ne 0 ]; then
    print_error "Failed to execute Change Set"
    exit 1
fi

print_info "${GREEN}Change Set execution started successfully${NC}"
print_info ""
print_info "Waiting for stack operation to complete..."
print_info "This may take several minutes..."

# Determine stack operation type
set +e
aws cloudformation describe-stacks \
    --stack-name $FULL_STACK_NAME \
    --region $REGION > /dev/null 2>&1

STACK_EXISTS=$?
set -e

if [ $STACK_EXISTS -eq 0 ]; then
    # Stack exists, wait for update
    aws cloudformation wait stack-update-complete \
        --stack-name $FULL_STACK_NAME \
        --region $REGION
else
    # New stack, wait for create
    aws cloudformation wait stack-create-complete \
        --stack-name $FULL_STACK_NAME \
        --region $REGION
fi

if [ $? -eq 0 ]; then
    print_info "${GREEN}Stack operation completed successfully!${NC}"
    print_info "Stack Name: $FULL_STACK_NAME"

    # Display stack outputs
    print_info "==================================================="
    print_info "Stack Outputs:"
    print_info "==================================================="

    aws cloudformation describe-stacks \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
        --output table

    # Display stack status
    print_info "==================================================="
    print_info "Stack Status:"
    print_info "==================================================="

    aws cloudformation describe-stacks \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].[StackName,StackStatus,LastUpdatedTime]' \
        --output table

else
    print_error "Stack operation failed"

    # Display failure details
    print_error "==================================================="
    print_error "Failure details:"
    print_error "==================================================="

    aws cloudformation describe-stack-events \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId, ResourceStatusReason]' \
        --output table

    print_error ""
    print_error "To rollback, run:"
    print_error "  ./scripts/rollback.sh $ENVIRONMENT $LAYER $STACK_NAME_BASE"

    exit 1
fi

print_info "==================================================="
print_info "${GREEN}Deployment completed successfully!${NC}"
print_info "==================================================="
