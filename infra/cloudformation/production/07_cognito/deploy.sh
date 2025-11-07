#!/bin/bash
set -euo pipefail

# ==============================================================================
# CloudFormation Cognito Stack Deployment
# ==============================================================================
# 目的: Cognito関連リソースのデプロイ（Change Sets必須）
# 影響: User Pool、Identity Pool、Lambda、DynamoDBを作成・更新
# 前提: AWS CLI設定済み、適切なIAM権限
# ==============================================================================

# 変数設定
PROJECT_NAME="kaigo-subsys"
ENVIRONMENT="prod"
REGION="ap-northeast-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARAMETERS_FILE="${SCRIPT_DIR}/parameters.json"

# スタック名
DYNAMODB_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cognito-dynamodb"
LAMBDA_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cognito-lambda"
USER_POOL_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cognito-user-pool"
IDENTITY_POOL_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cognito-identity-pool"

# Change Set名（タイムスタンプ付き）
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "===================================="
echo "Cognito Stack Deployment"
echo "===================================="
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"
echo "===================================="
echo ""

# ------------------------------------------------------------------------------
# 関数: Change Set作成
# ------------------------------------------------------------------------------
create_change_set() {
    local stack_name=$1
    local template_file=$2
    local change_set_name="${stack_name}-${TIMESTAMP}"
    local stack_params=""

    echo "Creating Change Set: ${change_set_name}"

    # スタックが存在するか確認
    if aws cloudformation describe-stacks --stack-name "${stack_name}" --region "${REGION}" &>/dev/null; then
        local change_set_type="UPDATE"
        echo "Stack exists. Change Set Type: UPDATE"
    else
        local change_set_type="CREATE"
        echo "Stack does not exist. Change Set Type: CREATE"
    fi

    # パラメータファイルを使用する場合
    if [ "$3" = "use-params" ]; then
        stack_params="--parameters file://${PARAMETERS_FILE}"
    fi

    # Change Set作成
    aws cloudformation create-change-set \
        --stack-name "${stack_name}" \
        --change-set-name "${change_set_name}" \
        --template-body "file://${template_file}" \
        --change-set-type "${change_set_type}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "${REGION}" \
        ${stack_params} \
        > /dev/null

    echo "Waiting for Change Set creation..."
    aws cloudformation wait change-set-create-complete \
        --stack-name "${stack_name}" \
        --change-set-name "${change_set_name}" \
        --region "${REGION}" || {
            echo "Change Set creation failed. Checking status..."
            local status=$(aws cloudformation describe-change-set \
                --stack-name "${stack_name}" \
                --change-set-name "${change_set_name}" \
                --region "${REGION}" \
                --query 'Status' --output text)

            if [ "$status" = "FAILED" ]; then
                local reason=$(aws cloudformation describe-change-set \
                    --stack-name "${stack_name}" \
                    --change-set-name "${change_set_name}" \
                    --region "${REGION}" \
                    --query 'StatusReason' --output text)

                if [[ "$reason" == *"didn't contain changes"* ]]; then
                    echo "No changes detected. Skipping..."
                    return 0
                else
                    echo "Error: ${reason}"
                    return 1
                fi
            fi
        }

    echo "✅ Change Set created: ${change_set_name}"
    echo "${change_set_name}" > /tmp/changeset-${stack_name}.txt
}

# ------------------------------------------------------------------------------
# 関数: Change Set詳細表示（dry-run）
# ------------------------------------------------------------------------------
describe_change_set() {
    local stack_name=$1
    local change_set_name=$(cat /tmp/changeset-${stack_name}.txt 2>/dev/null || echo "")

    if [ -z "$change_set_name" ]; then
        echo "No Change Set found for ${stack_name}"
        return 0
    fi

    echo ""
    echo "===================================="
    echo "Change Set Details: ${stack_name}"
    echo "===================================="

    aws cloudformation describe-change-set \
        --stack-name "${stack_name}" \
        --change-set-name "${change_set_name}" \
        --region "${REGION}" \
        --query 'Changes[].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}' \
        --output table

    echo ""
}

# ------------------------------------------------------------------------------
# 関数: Change Set実行
# ------------------------------------------------------------------------------
execute_change_set() {
    local stack_name=$1
    local change_set_name=$(cat /tmp/changeset-${stack_name}.txt 2>/dev/null || echo "")

    if [ -z "$change_set_name" ]; then
        echo "No Change Set to execute for ${stack_name}"
        return 0
    fi

    echo "Executing Change Set: ${change_set_name}"

    # 本番環境のみ承認プロンプト
    if [ "${ENVIRONMENT}" = "prod" ]; then
        read -p "Execute Change Set '${change_set_name}' on ${stack_name}? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Deployment cancelled."
            exit 0
        fi
    fi

    aws cloudformation execute-change-set \
        --stack-name "${stack_name}" \
        --change-set-name "${change_set_name}" \
        --region "${REGION}"

    echo "Waiting for stack operation to complete..."

    # スタック操作の完了を待機
    if aws cloudformation describe-stacks --stack-name "${stack_name}" --region "${REGION}" &>/dev/null; then
        aws cloudformation wait stack-update-complete \
            --stack-name "${stack_name}" \
            --region "${REGION}" 2>/dev/null || \
        aws cloudformation wait stack-create-complete \
            --stack-name "${stack_name}" \
            --region "${REGION}"
    fi

    echo "✅ Stack operation completed: ${stack_name}"
    rm -f /tmp/changeset-${stack_name}.txt
}

# ==============================================================================
# デプロイ実行（依存関係順）
# ==============================================================================

# 1. DynamoDB Tables（Lambda トリガーが依存）
echo "Step 1/4: Deploying DynamoDB Tables..."
create_change_set "${DYNAMODB_STACK_NAME}" "${SCRIPT_DIR}/cognito-dynamodb-tables.yaml" "use-params"
describe_change_set "${DYNAMODB_STACK_NAME}"
execute_change_set "${DYNAMODB_STACK_NAME}"
echo ""

# DynamoDB テーブル名を取得
LOGIN_ATTEMPTS_TABLE=$(aws cloudformation describe-stacks \
    --stack-name "${DYNAMODB_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`LoginAttemptsTableName`].OutputValue' \
    --output text)

MFA_BACKUP_CODES_TABLE=$(aws cloudformation describe-stacks \
    --stack-name "${DYNAMODB_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`MfaBackupCodesTableName`].OutputValue' \
    --output text)

echo "DynamoDB Tables:"
echo "  - LoginAttemptsTable: ${LOGIN_ATTEMPTS_TABLE}"
echo "  - MfaBackupCodesTable: ${MFA_BACKUP_CODES_TABLE}"
echo ""

# 2. Lambda Triggers（User Pool が依存）
echo "Step 2/4: Deploying Lambda Triggers..."

# Lambda用パラメータファイルを一時生成
LAMBDA_PARAMS_FILE="/tmp/lambda-params-${TIMESTAMP}.json"
cat > "${LAMBDA_PARAMS_FILE}" <<EOF
[
  {"ParameterKey": "ProjectName", "ParameterValue": "${PROJECT_NAME}"},
  {"ParameterKey": "Environment", "ParameterValue": "${ENVIRONMENT}"},
  {"ParameterKey": "LoginAttemptsTableName", "ParameterValue": "${LOGIN_ATTEMPTS_TABLE}"},
  {"ParameterKey": "MfaBackupCodesTableName", "ParameterValue": "${MFA_BACKUP_CODES_TABLE}"}
]
EOF

aws cloudformation create-change-set \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --change-set-name "${LAMBDA_STACK_NAME}-${TIMESTAMP}" \
    --template-body "file://${SCRIPT_DIR}/cognito-lambda-triggers.yaml" \
    --change-set-type $(aws cloudformation describe-stacks --stack-name "${LAMBDA_STACK_NAME}" --region "${REGION}" &>/dev/null && echo "UPDATE" || echo "CREATE") \
    --parameters "file://${LAMBDA_PARAMS_FILE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}" \
    > /dev/null

echo "${LAMBDA_STACK_NAME}-${TIMESTAMP}" > /tmp/changeset-${LAMBDA_STACK_NAME}.txt

aws cloudformation wait change-set-create-complete \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --change-set-name "${LAMBDA_STACK_NAME}-${TIMESTAMP}" \
    --region "${REGION}" 2>/dev/null || true

describe_change_set "${LAMBDA_STACK_NAME}"
execute_change_set "${LAMBDA_STACK_NAME}"

rm -f "${LAMBDA_PARAMS_FILE}"
echo ""

# Lambda ARNを取得
PRE_AUTH_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`PreAuthFunctionArn`].OutputValue' \
    --output text)

POST_AUTH_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`PostAuthFunctionArn`].OutputValue' \
    --output text)

POST_CONFIRM_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`PostConfirmFunctionArn`].OutputValue' \
    --output text)

PRE_TOKEN_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`PreTokenFunctionArn`].OutputValue' \
    --output text)

CUSTOM_MESSAGE_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${LAMBDA_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`CustomMessageFunctionArn`].OutputValue' \
    --output text)

echo "Lambda Functions:"
echo "  - PreAuth: ${PRE_AUTH_ARN}"
echo "  - PostAuth: ${POST_AUTH_ARN}"
echo "  - PostConfirm: ${POST_CONFIRM_ARN}"
echo "  - PreToken: ${PRE_TOKEN_ARN}"
echo "  - CustomMessage: ${CUSTOM_MESSAGE_ARN}"
echo ""

# 3. User Pool（Identity Pool が依存）
echo "Step 3/4: Deploying User Pool..."

# User Pool用パラメータファイルを一時生成
USER_POOL_PARAMS_FILE="/tmp/user-pool-params-${TIMESTAMP}.json"
jq ". + [
  {\"ParameterKey\": \"PreAuthFunctionArn\", \"ParameterValue\": \"${PRE_AUTH_ARN}\"},
  {\"ParameterKey\": \"PostAuthFunctionArn\", \"ParameterValue\": \"${POST_AUTH_ARN}\"},
  {\"ParameterKey\": \"PostConfirmFunctionArn\", \"ParameterValue\": \"${POST_CONFIRM_ARN}\"},
  {\"ParameterKey\": \"PreTokenFunctionArn\", \"ParameterValue\": \"${PRE_TOKEN_ARN}\"},
  {\"ParameterKey\": \"CustomMessageFunctionArn\", \"ParameterValue\": \"${CUSTOM_MESSAGE_ARN}\"}
]" "${PARAMETERS_FILE}" > "${USER_POOL_PARAMS_FILE}"

aws cloudformation create-change-set \
    --stack-name "${USER_POOL_STACK_NAME}" \
    --change-set-name "${USER_POOL_STACK_NAME}-${TIMESTAMP}" \
    --template-body "file://${SCRIPT_DIR}/cognito-user-pool.yaml" \
    --change-set-type $(aws cloudformation describe-stacks --stack-name "${USER_POOL_STACK_NAME}" --region "${REGION}" &>/dev/null && echo "UPDATE" || echo "CREATE") \
    --parameters "file://${USER_POOL_PARAMS_FILE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}" \
    > /dev/null

echo "${USER_POOL_STACK_NAME}-${TIMESTAMP}" > /tmp/changeset-${USER_POOL_STACK_NAME}.txt

aws cloudformation wait change-set-create-complete \
    --stack-name "${USER_POOL_STACK_NAME}" \
    --change-set-name "${USER_POOL_STACK_NAME}-${TIMESTAMP}" \
    --region "${REGION}" 2>/dev/null || true

describe_change_set "${USER_POOL_STACK_NAME}"
execute_change_set "${USER_POOL_STACK_NAME}"

rm -f "${USER_POOL_PARAMS_FILE}"
echo ""

# User Pool IDを取得
USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name "${USER_POOL_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "${USER_POOL_STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

echo "User Pool:"
echo "  - UserPoolId: ${USER_POOL_ID}"
echo "  - ClientId: ${USER_POOL_CLIENT_ID}"
echo ""

# 4. Identity Pool
echo "Step 4/4: Deploying Identity Pool..."

# Identity Pool用パラメータファイルを一時生成
IDENTITY_POOL_PARAMS_FILE="/tmp/identity-pool-params-${TIMESTAMP}.json"
jq ". + [
  {\"ParameterKey\": \"UserPoolId\", \"ParameterValue\": \"${USER_POOL_ID}\"},
  {\"ParameterKey\": \"UserPoolClientId\", \"ParameterValue\": \"${USER_POOL_CLIENT_ID}\"}
]" "${PARAMETERS_FILE}" > "${IDENTITY_POOL_PARAMS_FILE}"

aws cloudformation create-change-set \
    --stack-name "${IDENTITY_POOL_STACK_NAME}" \
    --change-set-name "${IDENTITY_POOL_STACK_NAME}-${TIMESTAMP}" \
    --template-body "file://${SCRIPT_DIR}/cognito-identity-pool.yaml" \
    --change-set-type $(aws cloudformation describe-stacks --stack-name "${IDENTITY_POOL_STACK_NAME}" --region "${REGION}" &>/dev/null && echo "UPDATE" || echo "CREATE") \
    --parameters "file://${IDENTITY_POOL_PARAMS_FILE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}" \
    > /dev/null

echo "${IDENTITY_POOL_STACK_NAME}-${TIMESTAMP}" > /tmp/changeset-${IDENTITY_POOL_STACK_NAME}.txt

aws cloudformation wait change-set-create-complete \
    --stack-name "${IDENTITY_POOL_STACK_NAME}" \
    --change-set-name "${IDENTITY_POOL_STACK_NAME}-${TIMESTAMP}" \
    --region "${REGION}" 2>/dev/null || true

describe_change_set "${IDENTITY_POOL_STACK_NAME}"
execute_change_set "${IDENTITY_POOL_STACK_NAME}"

rm -f "${IDENTITY_POOL_PARAMS_FILE}"
echo ""

# ==============================================================================
# 完了
# ==============================================================================
echo "===================================="
echo "✅ All Cognito Stacks Deployed"
echo "===================================="
echo ""
echo "Next Steps:"
echo "1. Test user creation: aws cognito-idp admin-create-user --user-pool-id ${USER_POOL_ID} --username test@example.com"
echo "2. Configure frontend with User Pool ID and Client ID"
echo "3. Test MFA setup and login flow"
echo ""
