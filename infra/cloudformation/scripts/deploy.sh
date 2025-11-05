#!/bin/bash

###############################################################################
# CloudFormation Stack Deployment Script
#
# Usage: ./deploy.sh <environment> <layer> <stack-name>
# Example: ./deploy.sh production 02_network vpc-core-stack
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

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFN_DIR="${SCRIPT_DIR}/.."
TEMPLATE_FILE="${CFN_DIR}/${ENVIRONMENT}/${LAYER}/${STACK_NAME_BASE}.yaml"
PARAMS_FILE="${CFN_DIR}/parameters/${ENVIRONMENT}/${STACK_NAME_BASE}-params.json"

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: production, staging"
    exit 1
fi

# Validate template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

print_info "==================================================="
print_info "CloudFormation Stack Deployment"
print_info "==================================================="
print_info "Environment:  $ENVIRONMENT"
print_info "Layer:        $LAYER"
print_info "Stack Name:   $FULL_STACK_NAME"
print_info "Template:     $TEMPLATE_FILE"
print_info "Parameters:   $PARAMS_FILE"
print_info "Region:       $REGION"
print_info "==================================================="

# Validate template
print_info "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://"$TEMPLATE_FILE" \
    --region $REGION > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_info "Template validation: ${GREEN}PASSED${NC}"
else
    print_error "Template validation: ${RED}FAILED${NC}"
    exit 1
fi

# Check if stack exists
print_info "Checking if stack exists..."
aws cloudformation describe-stacks \
    --stack-name $FULL_STACK_NAME \
    --region $REGION > /dev/null 2>&1

STACK_EXISTS=$?

# Create Change Set name with timestamp
CHANGE_SET_NAME="${FULL_STACK_NAME}-$(date +%Y%m%d%H%M%S)"

if [ $STACK_EXISTS -eq 0 ]; then
    print_warn "Stack exists. Creating UPDATE change set..."
    CHANGE_SET_TYPE="UPDATE"
else
    print_info "Stack does not exist. Creating CREATE change set..."
    CHANGE_SET_TYPE="CREATE"
fi

# Build parameters option
PARAMS_OPTION=""
if [ -f "$PARAMS_FILE" ]; then
    PARAMS_OPTION="--parameters file://${PARAMS_FILE}"
    print_info "Using parameter file: $PARAMS_FILE"
else
    print_warn "No parameter file found. Using template defaults."
fi

# Create Change Set
print_info "Creating Change Set: $CHANGE_SET_NAME"

aws cloudformation create-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --change-set-type $CHANGE_SET_TYPE \
    --template-body file://"$TEMPLATE_FILE" \
    $PARAMS_OPTION \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags \
        Key=Environment,Value=$ENVIRONMENT \
        Key=Project,Value=$PROJECT_NAME \
        Key=ManagedBy,Value=CloudFormation \
    --region $REGION

if [ $? -ne 0 ]; then
    print_error "Failed to create Change Set"
    exit 1
fi

print_info "Waiting for Change Set to be created..."

aws cloudformation wait change-set-create-complete \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION

if [ $? -ne 0 ]; then
    print_error "Change Set creation failed or timed out"

    # Check if change set has no changes
    CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
        --stack-name $FULL_STACK_NAME \
        --change-set-name $CHANGE_SET_NAME \
        --region $REGION \
        --query 'Status' \
        --output text)

    if [ "$CHANGE_SET_STATUS" == "FAILED" ]; then
        CHANGE_SET_STATUS_REASON=$(aws cloudformation describe-change-set \
            --stack-name $FULL_STACK_NAME \
            --change-set-name $CHANGE_SET_NAME \
            --region $REGION \
            --query 'StatusReason' \
            --output text)

        if [[ "$CHANGE_SET_STATUS_REASON" == *"didn't contain changes"* ]]; then
            print_warn "No changes detected in the stack"
            print_info "Deleting empty Change Set..."
            aws cloudformation delete-change-set \
                --stack-name $FULL_STACK_NAME \
                --change-set-name $CHANGE_SET_NAME \
                --region $REGION
            print_info "Stack is already up to date"
            exit 0
        fi
    fi
    exit 1
fi

print_info "${GREEN}Change Set created successfully${NC}"

# Display Change Set
print_info "Change Set details:"
print_info "==================================================="

aws cloudformation describe-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION \
    --query 'Changes[*].[Type, ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType]' \
    --output table

print_info "==================================================="

# Ask for confirmation
echo ""
read -p "Do you want to execute this Change Set? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    print_warn "Deployment cancelled by user"
    print_info "Deleting Change Set..."
    aws cloudformation delete-change-set \
        --stack-name $FULL_STACK_NAME \
        --change-set-name $CHANGE_SET_NAME \
        --region $REGION
    exit 0
fi

# Execute Change Set
print_info "Executing Change Set..."

aws cloudformation execute-change-set \
    --stack-name $FULL_STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION

if [ $? -ne 0 ]; then
    print_error "Failed to execute Change Set"
    exit 1
fi

print_info "Waiting for stack operation to complete..."
print_info "This may take several minutes..."

if [ "$CHANGE_SET_TYPE" == "CREATE" ]; then
    aws cloudformation wait stack-create-complete \
        --stack-name $FULL_STACK_NAME \
        --region $REGION
else
    aws cloudformation wait stack-update-complete \
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
else
    print_error "Stack operation failed"

    # Display failure reason
    print_error "Failure details:"
    aws cloudformation describe-stack-events \
        --stack-name $FULL_STACK_NAME \
        --region $REGION \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId, ResourceStatusReason]' \
        --output table

    exit 1
fi

print_info "==================================================="
print_info "${GREEN}Deployment completed successfully!${NC}"
print_info "==================================================="
