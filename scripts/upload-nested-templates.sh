#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <environment>"
  echo "  environment: dev, staging, production"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

ENVIRONMENT=$1
PROJECT_NAME="niigata-kaigo"
BUCKET_NAME="${PROJECT_NAME}-cfn-templates-${ENVIRONMENT}"
AWS_REGION=${AWS_REGION:-ap-northeast-1}

echo "========================================"
echo "Nested Stack Templates Upload"
echo "========================================"
echo "Environment: ${ENVIRONMENT}"
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

# Check if bucket exists
echo "Checking S3 bucket..."
if ! aws s3 ls "s3://${BUCKET_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Creating S3 bucket..."
  if [ "${AWS_REGION}" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
  
  aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  
  echo "✅ Bucket created"
else
  echo "✅ Bucket exists"
fi

echo ""
echo "Uploading Common Account templates..."
aws s3 sync infra/common/cloudformation/templates/ \
  "s3://${BUCKET_NAME}/common/templates/" \
  --region "${AWS_REGION}" --delete --exclude "*.md"

echo ""
echo "Uploading App Account templates..."
aws s3 sync infra/app/cloudformation/templates/ \
  "s3://${BUCKET_NAME}/app/templates/" \
  --region "${AWS_REGION}" --delete --exclude "*.md"

echo ""
echo "✅ Upload completed!"
aws s3 ls "s3://${BUCKET_NAME}/" --recursive --region "${AWS_REGION}"
