#!/bin/bash

##############################################################################
# Upload CloudFormation Templates to S3
#
# Usage:
#   ./scripts/upload-templates.sh <environment>
#
# Arguments:
#   environment: 'dev' | 'staging' | 'production'
#
# Examples:
#   # Upload templates for dev environment
#   ./scripts/upload-templates.sh dev
#
#   # Upload templates for production environment
#   ./scripts/upload-templates.sh production
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
if [ $# -lt 1 ]; then
    error "Usage: $0 <environment>"
    error "  environment: 'dev' | 'staging' | 'production'"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    error "Invalid environment: $ENVIRONMENT. Must be 'dev', 'staging', or 'production'"
    exit 1
fi

# Set bucket name based on environment
BUCKET_NAME="niigata-kaigo-cfn-templates-${ENVIRONMENT}"
REGION="ap-northeast-1"

info "=================================================="
info "Upload CloudFormation Templates to S3"
info "=================================================="
info "Environment: $ENVIRONMENT"
info "Bucket:      s3://$BUCKET_NAME"
info "Region:      $REGION"
info "=================================================="

# Step 1: Check if bucket exists
info "Checking if S3 bucket exists..."

set +e
aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null
BUCKET_EXISTS=$?
set -e

if [ $BUCKET_EXISTS -ne 0 ]; then
    warning "S3 bucket does not exist: s3://$BUCKET_NAME"
    warning "Creating bucket..."

    aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"

    success "Bucket created: s3://$BUCKET_NAME"
else
    success "Bucket exists: s3://$BUCKET_NAME"
fi

# Step 2: Upload templates for 共通アカウント
info "=================================================="
info "Uploading templates for 共通アカウント..."
info "=================================================="

aws s3 sync "infra/共通アカウント/cloudformation/templates/" \
    "s3://$BUCKET_NAME/共通アカウント/templates/" \
    --region "$REGION" \
    --delete

success "Templates uploaded: 共通アカウント"

# Step 3: Upload templates for appアカウント
info "=================================================="
info "Uploading templates for appアカウント..."
info "=================================================="

aws s3 sync "infra/appアカウント/cloudformation/templates/" \
    "s3://$BUCKET_NAME/appアカウント/templates/" \
    --region "$REGION" \
    --delete

success "Templates uploaded: appアカウント"

# Step 4: List uploaded files
info "=================================================="
info "Uploaded Files:"
info "=================================================="

aws s3 ls "s3://$BUCKET_NAME/" --recursive --human-readable

success "All templates uploaded successfully!"
