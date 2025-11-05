#!/bin/bash

###############################################################################
# CloudFormation Template Validation Script
#
# Usage: ./validate.sh <template-file>
# Example: ./validate.sh production/02_network/vpc-core-stack.yaml
###############################################################################

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

REGION="ap-northeast-1"

if [ $# -ne 1 ]; then
    echo -e "${RED}[ERROR]${NC} Invalid number of arguments"
    echo "Usage: $0 <template-file>"
    echo "Example: $0 production/02_network/vpc-core-stack.yaml"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFN_DIR="${SCRIPT_DIR}/.."
TEMPLATE_FILE="${CFN_DIR}/$1"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Template file not found: $TEMPLATE_FILE"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Validating template: $TEMPLATE_FILE"

aws cloudformation validate-template \
    --template-body file://"$TEMPLATE_FILE" \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Template validation passed"
else
    echo -e "${RED}[FAILED]${NC} Template validation failed"
    exit 1
fi
