#!/bin/bash

###############################################################################
# Simple CloudFormation Deployment Script (for new structure)
#
# Usage: ./simple-deploy.sh <stack-name> <template-path> <params-path>
# Example: ./simple-deploy.sh niigata-kaigo-staging-vpc-core-stack \
#          templates/network/vpc-and-igw.yaml \
#          parameters/staging/vpc-core-stack-params.json
###############################################################################

set -e

REGION="ap-northeast-1"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <stack-name> <template-path> <params-path>"
    exit 1
fi

STACK_NAME=$1
TEMPLATE_PATH=$2
PARAMS_PATH=$3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFN_DIR="${SCRIPT_DIR}/.."

TEMPLATE_FULL="${CFN_DIR}/${TEMPLATE_PATH}"
PARAMS_FULL="${CFN_DIR}/${PARAMS_PATH}"

echo "==================================================="
echo "CloudFormation Deployment"
echo "==================================================="
echo "Stack:      $STACK_NAME"
echo "Template:   $TEMPLATE_FULL"
echo "Parameters: $PARAMS_FULL"
echo "Region:     $REGION"
echo "==================================================="

# Check if stack exists
set +e
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION > /dev/null 2>&1
STACK_EXISTS=$?
set -e

CHANGE_SET_NAME="${STACK_NAME}-$(date +%Y%m%d%H%M%S)"

if [ $STACK_EXISTS -eq 0 ]; then
    CHANGE_SET_TYPE="UPDATE"
    echo "Stack exists. Creating UPDATE change set..."
else
    CHANGE_SET_TYPE="CREATE"
    echo "Stack does not exist. Creating CREATE change set..."
fi

# Create Change Set
echo "Creating Change Set: $CHANGE_SET_NAME"

aws cloudformation create-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --change-set-type $CHANGE_SET_TYPE \
    --template-body file://"$TEMPLATE_FULL" \
    --parameters file://"$PARAMS_FULL" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo "Waiting for Change Set to be created..."

aws cloudformation wait change-set-create-complete \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION 2>&1 || true

# Check status
CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION \
    --query 'Status' \
    --output text)

if [ "$CHANGE_SET_STATUS" == "FAILED" ]; then
    REASON=$(aws cloudformation describe-change-set \
        --stack-name $STACK_NAME \
        --change-set-name $CHANGE_SET_NAME \
        --region $REGION \
        --query 'StatusReason' \
        --output text)

    if [[ "$REASON" == *"didn't contain changes"* ]]; then
        echo "No changes detected. Stack is up to date."
        aws cloudformation delete-change-set \
            --stack-name $STACK_NAME \
            --change-set-name $CHANGE_SET_NAME \
            --region $REGION
        exit 0
    else
        echo "Change Set creation failed: $REASON"
        exit 1
    fi
fi

# Display changes
echo "==================================================="
echo "Change Set Details:"
echo "==================================================="

aws cloudformation describe-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION \
    --query 'Changes[*].[Type, ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType]' \
    --output table

echo "==================================================="
echo ""
read -p "Execute this Change Set? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo "Cancelled. Deleting Change Set..."
    aws cloudformation delete-change-set \
        --stack-name $STACK_NAME \
        --change-set-name $CHANGE_SET_NAME \
        --region $REGION
    exit 0
fi

# Execute
echo "Executing Change Set..."

aws cloudformation execute-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION

echo "Waiting for stack operation to complete..."

if [ "$CHANGE_SET_TYPE" == "CREATE" ]; then
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME \
        --region $REGION
else
    aws cloudformation wait stack-update-complete \
        --stack-name $STACK_NAME \
        --region $REGION
fi

echo "==================================================="
echo "Deployment completed successfully!"
echo "==================================================="

# Display outputs
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
    --output table
