#!/bin/bash

###############################################################################
# CloudFormation Phase-based Deployment Script
#
# This script deploys CloudFormation stacks in a specific phase, ensuring
# proper dependency order and error handling.
#
# Usage: ./deploy-phase.sh <environment> <phase>
# Example: ./deploy-phase.sh staging phase1
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

print_phase() {
    echo -e "${BLUE}[PHASE]${NC} $1"
}

# Validate arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <environment> <phase>"
    echo ""
    echo "Available phases:"
    echo "  phase1  - 監査・ネットワーク基盤 (CloudTrail, AWS Config, VPC, Subnets, NAT, Routes)"
    echo "  phase2  - セキュリティ (KMS, Security Groups)"
    echo "  phase3  - データ層 (RDS)"
    echo "  phase4  - コンピューティング (ALB, ECS)"
    echo "  phase5  - ストレージ・認証 (S3, Cognito)"
    echo ""
    echo "Example: $0 staging phase1"
    exit 1
fi

ENVIRONMENT=$1
PHASE=$2

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: production, staging"
    exit 1
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deploy a single stack
deploy_stack() {
    local layer=$1
    local stack_name=$2

    print_info "Deploying: $layer/$stack_name"

    # Use the existing deploy.sh script
    bash "$SCRIPT_DIR/deploy.sh" "$ENVIRONMENT" "$layer" "$stack_name" <<< "yes"

    if [ $? -ne 0 ]; then
        print_error "Failed to deploy $layer/$stack_name"
        return 1
    fi

    print_info "${GREEN}Successfully deployed: $layer/$stack_name${NC}"
    return 0
}

# Phase definitions
case "$PHASE" in
    "phase1")
        print_phase "==================================================="
        print_phase "Phase 1: 監査・ネットワーク基盤"
        print_phase "==================================================="
        print_phase "Stacks:"
        print_phase "  - CloudTrail (監査ログ)"
        print_phase "  - AWS Config (コンプライアンス)"
        print_phase "  - VPC Core (VPC + IGW)"
        print_phase "  - Subnets (Public/Private)"
        print_phase "  - NAT Gateways"
        print_phase "  - Route Tables"
        print_phase "==================================================="

        # Deploy stacks in order
        deploy_stack "01_audit" "cloudtrail-stack" || exit 1
        deploy_stack "01_audit" "aws-config-stack" || exit 1
        deploy_stack "02_network" "vpc-core-stack" || exit 1
        deploy_stack "02_network" "subnets-stack" || exit 1
        deploy_stack "02_network" "nat-gateways-stack" || exit 1
        deploy_stack "02_network" "route-tables-stack" || exit 1
        ;;

    "phase2")
        print_phase "==================================================="
        print_phase "Phase 2: セキュリティ"
        print_phase "==================================================="
        print_phase "Stacks:"
        print_phase "  - KMS (暗号化キー)"
        print_phase "  - Security Groups (ALB, ECS, RDS)"
        print_phase "==================================================="

        # Check Phase 1 completion
        print_info "Checking Phase 1 dependencies..."
        required_stacks=("${PROJECT_NAME}-${ENVIRONMENT}-vpc-core-stack")
        for stack in "${required_stacks[@]}"; do
            aws cloudformation describe-stacks \
                --stack-name "$stack" \
                --region $REGION > /dev/null 2>&1 || {
                print_error "Required stack not found: $stack"
                print_error "Please deploy Phase 1 first."
                exit 1
            }
        done

        # Deploy stacks in order
        deploy_stack "03_security" "kms-stack" || exit 1
        deploy_stack "03_security" "security-groups-stack" || exit 1
        ;;

    "phase3")
        print_phase "==================================================="
        print_phase "Phase 3: データ層"
        print_phase "==================================================="
        print_phase "Stacks:"
        print_phase "  - RDS MySQL (Multi-AZ)"
        print_phase "==================================================="

        # Check Phase 1 & 2 completion
        print_info "Checking Phase 1 & 2 dependencies..."
        required_stacks=(
            "${PROJECT_NAME}-${ENVIRONMENT}-vpc-core-stack"
            "${PROJECT_NAME}-${ENVIRONMENT}-subnets-stack"
            "${PROJECT_NAME}-${ENVIRONMENT}-security-groups-stack"
        )
        for stack in "${required_stacks[@]}"; do
            aws cloudformation describe-stacks \
                --stack-name "$stack" \
                --region $REGION > /dev/null 2>&1 || {
                print_error "Required stack not found: $stack"
                print_error "Please deploy Phase 1 and Phase 2 first."
                exit 1
            }
        done

        # Deploy stacks in order
        deploy_stack "05_data" "rds-stack" || exit 1
        ;;

    "phase4")
        print_phase "==================================================="
        print_phase "Phase 4: コンピューティング"
        print_phase "==================================================="
        print_phase "Stacks:"
        print_phase "  - ALB (Application Load Balancer)"
        print_phase "  - ECS (Fargate Cluster + Services)"
        print_phase "==================================================="

        # Check Phase 1 & 2 completion
        print_info "Checking Phase 1 & 2 dependencies..."
        required_stacks=(
            "${PROJECT_NAME}-${ENVIRONMENT}-vpc-core-stack"
            "${PROJECT_NAME}-${ENVIRONMENT}-subnets-stack"
            "${PROJECT_NAME}-${ENVIRONMENT}-security-groups-stack"
        )
        for stack in "${required_stacks[@]}"; do
            aws cloudformation describe-stacks \
                --stack-name "$stack" \
                --region $REGION > /dev/null 2>&1 || {
                print_error "Required stack not found: $stack"
                print_error "Please deploy Phase 1 and Phase 2 first."
                exit 1
            }
        done

        # Deploy stacks in order
        deploy_stack "04_compute" "alb-stack" || exit 1
        deploy_stack "04_compute" "ecs-stack" || exit 1
        ;;

    "phase5")
        print_phase "==================================================="
        print_phase "Phase 5: ストレージ・認証"
        print_phase "==================================================="
        print_phase "Stacks:"
        print_phase "  - S3 (Frontend hosting)"
        print_phase "  - Cognito User Pool"
        print_phase "  - Cognito Identity Pool"
        print_phase "  - Cognito DynamoDB Tables"
        print_phase "  - Cognito Lambda Triggers"
        print_phase "==================================================="

        # Check Phase 2 completion
        print_info "Checking Phase 2 dependencies..."
        required_stacks=(
            "${PROJECT_NAME}-${ENVIRONMENT}-kms-stack"
        )
        for stack in "${required_stacks[@]}"; do
            aws cloudformation describe-stacks \
                --stack-name "$stack" \
                --region $REGION > /dev/null 2>&1 || {
                print_error "Required stack not found: $stack"
                print_error "Please deploy Phase 2 first."
                exit 1
            }
        done

        # Deploy stacks in order
        deploy_stack "06_storage" "s3-stack" || exit 1
        deploy_stack "07_cognito" "cognito-user-pool" || exit 1
        deploy_stack "07_cognito" "cognito-identity-pool" || exit 1
        deploy_stack "07_cognito" "cognito-dynamodb-tables" || exit 1
        deploy_stack "07_cognito" "cognito-lambda-triggers" || exit 1
        ;;

    *)
        print_error "Invalid phase: $PHASE"
        echo ""
        echo "Available phases:"
        echo "  phase1  - 監査・ネットワーク基盤"
        echo "  phase2  - セキュリティ"
        echo "  phase3  - データ層"
        echo "  phase4  - コンピューティング"
        echo "  phase5  - ストレージ・認証"
        exit 1
        ;;
esac

print_phase ""
print_phase "==================================================="
print_phase "${GREEN}Phase $PHASE deployment completed successfully!${NC}"
print_phase "==================================================="
print_phase ""
print_phase "Next steps:"

case "$PHASE" in
    "phase1")
        print_phase "  ./deploy-phase.sh $ENVIRONMENT phase2"
        ;;
    "phase2")
        print_phase "  ./deploy-phase.sh $ENVIRONMENT phase3  (データ層)"
        print_phase "  ./deploy-phase.sh $ENVIRONMENT phase4  (コンピューティング)"
        ;;
    "phase3")
        print_phase "  ./deploy-phase.sh $ENVIRONMENT phase4"
        ;;
    "phase4")
        print_phase "  ./deploy-phase.sh $ENVIRONMENT phase5"
        ;;
    "phase5")
        print_phase "  All phases completed!"
        ;;
esac

print_phase "==================================================="
