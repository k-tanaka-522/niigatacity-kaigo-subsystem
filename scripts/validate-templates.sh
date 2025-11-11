#!/bin/bash

#######################################
# CloudFormation Template Validation Script
# Description: Validates all CloudFormation templates for syntax errors
# Usage: ./scripts/validate-templates.sh
#######################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
SUCCESS=0
FAILED=0

echo "========================================"
echo "CloudFormation Template Validation"
echo "========================================"
echo ""

# Function to validate a template
validate_template() {
  local template_path=$1
  local template_name=$(basename "$template_path")

  TOTAL=$((TOTAL + 1))

  echo -n "Validating: ${template_name}... "

  # Windows環境での file:// プレフィックス問題回避のため、テンプレートを直接読み込む
  local template_body=$(cat "${template_path}")

  if aws cloudformation validate-template \
    --template-body "${template_body}" \
    --region ap-northeast-1 \
    --output text > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    SUCCESS=$((SUCCESS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    FAILED=$((FAILED + 1))
    echo -e "${RED}Error details:${NC}"
    aws cloudformation validate-template \
      --template-body "${template_body}" \
      --region ap-northeast-1 2>&1 | tail -5
    echo ""
  fi
}

echo "----------------------------------------"
echo "Common Account Templates"
echo "----------------------------------------"

# Common Account: Audit Templates
if [ -d "infra/common/cloudformation/templates/audit" ]; then
  for template in infra/common/cloudformation/templates/audit/*.yaml; do
    validate_template "$template"
  done
fi

# Common Account: Monitoring Templates
if [ -d "infra/common/cloudformation/templates/monitoring" ]; then
  for template in infra/common/cloudformation/templates/monitoring/*.yaml; do
    validate_template "$template"
  done
fi

# Common Account: Network Templates
if [ -d "infra/common/cloudformation/templates/network" ]; then
  for template in infra/common/cloudformation/templates/network/*.yaml; do
    validate_template "$template"
  done
fi

# Common Account: Security Templates
if [ -d "infra/common/cloudformation/templates/security" ]; then
  for template in infra/common/cloudformation/templates/security/*.yaml; do
    validate_template "$template"
  done
fi

# Common Account: Storage Templates
if [ -d "infra/common/cloudformation/templates/storage" ]; then
  for template in infra/common/cloudformation/templates/storage/*.yaml; do
    validate_template "$template"
  done
fi

# Common Account: Stack Templates
if [ -d "infra/common/cloudformation/stacks" ]; then
  for stack_dir in infra/common/cloudformation/stacks/*/; do
    if [ -f "${stack_dir}main.yaml" ]; then
      validate_template "${stack_dir}main.yaml"
    fi
  done
fi

echo ""
echo "----------------------------------------"
echo "App Account Templates"
echo "----------------------------------------"

# App Account: Auth Templates
if [ -d "infra/app/cloudformation/templates/auth" ]; then
  for template in infra/app/cloudformation/templates/auth/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Compute Templates
if [ -d "infra/app/cloudformation/templates/compute" ]; then
  for template in infra/app/cloudformation/templates/compute/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Database Templates
if [ -d "infra/app/cloudformation/templates/database" ]; then
  for template in infra/app/cloudformation/templates/database/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Monitoring Templates
if [ -d "infra/app/cloudformation/templates/monitoring" ]; then
  for template in infra/app/cloudformation/templates/monitoring/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Network Templates
if [ -d "infra/app/cloudformation/templates/network" ]; then
  for template in infra/app/cloudformation/templates/network/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Security Templates
if [ -d "infra/app/cloudformation/templates/security" ]; then
  for template in infra/app/cloudformation/templates/security/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Storage Templates
if [ -d "infra/app/cloudformation/templates/storage" ]; then
  for template in infra/app/cloudformation/templates/storage/*.yaml; do
    validate_template "$template"
  done
fi

# App Account: Stack Templates
if [ -d "infra/app/cloudformation/stacks" ]; then
  for stack_dir in infra/app/cloudformation/stacks/*/; do
    if [ -f "${stack_dir}main.yaml" ]; then
      validate_template "${stack_dir}main.yaml"
    fi
  done
fi

echo ""
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo "Total:   ${TOTAL}"
echo -e "${GREEN}Success: ${SUCCESS}${NC}"
echo -e "${RED}Failed:  ${FAILED}${NC}"
echo ""

if [ ${FAILED} -eq 0 ]; then
  echo -e "${GREEN}✓ All templates are valid!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some templates have errors. Please fix them.${NC}"
  exit 1
fi
