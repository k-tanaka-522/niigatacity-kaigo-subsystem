# GitHub Actions CI/CD設計

## 目的
新潟市介護保険事業所システムの継続的インテグレーション・継続的デプロイメント（CI/CD）をGitHub Actionsで実現する。

## 影響範囲
- コードのテスト自動化
- ビルド・デプロイの自動化
- インフラ変更の自動検証
- セキュリティスキャン

## 前提条件
- GitHubリポジトリ使用
- AWSアカウント4つ（本番共通系、本番アプリ系、ステージング共通系、ステージングアプリ系）
- OIDC認証によるAWSアクセス

---

## ワークフロー全体像

| ワークフロー名 | トリガー | 対象 | デプロイ先 |
|-------------|---------|------|----------|
| **Frontend CI/CD** | push to `develop`, `main` | Next.jsアプリ | S3 + CloudFront |
| **Backend CI/CD** | push to `develop`, `main` | .NET Core API | ECS Fargate |
| **Infrastructure CI/CD** | push to `develop`, `main`<br>（infra/配下のみ） | CloudFormation | AWS各種リソース |

---

## AWS認証: OIDC（OpenID Connect）

### 概要

**従来の方法（非推奨）**:
- IAMユーザーのアクセスキー・シークレットをGitHub Secretsに保存
- 定期的なローテーションが必要
- 漏洩リスク

**OIDC認証（推奨）**:
- GitHub ActionsがAWS STSに一時的な認証情報を要求
- アクセスキー不要
- セキュリティ向上

### AWS側の設定

```json
// IAMロール: GitHubActionsDeployRole
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:niigata-city/kaigo-system:*"
        }
      }
    }
  ]
}
```

### GitHub Actions側の設定

```yaml
permissions:
  id-token: write  # OIDC認証に必要
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeployRole
          aws-region: ap-northeast-1
```

---

## ワークフロー1: Frontend CI/CD

### ファイルパス

`.github/workflows/frontend-deploy.yml`

### ワークフロー定義

```yaml
name: Frontend CI/CD

on:
  push:
    branches:
      - develop
      - main
    paths:
      - 'app/frontend/**'
      - '.github/workflows/frontend-deploy.yml'

permissions:
  id-token: write
  contents: read

env:
  NODE_VERSION: '20'

jobs:
  test:
    name: Test Frontend
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app/frontend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: app/frontend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Jest tests
        run: npm test -- --coverage

      - name: Build
        run: npm run build
        env:
          NODE_ENV: production

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: frontend-build
          path: app/frontend/.next
          retention-days: 7

  deploy-staging:
    name: Deploy to Staging
    needs: test
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.niigata-kaigo.example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: app/frontend/package-lock.json

      - name: Install dependencies
        run: npm ci
        working-directory: app/frontend

      - name: Build for staging
        run: npm run build
        working-directory: app/frontend
        env:
          NODE_ENV: production
          NEXT_PUBLIC_API_URL: ${{ secrets.STAGING_API_URL }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_STAGING }}
          aws-region: ap-northeast-1

      - name: Deploy to S3
        run: |
          aws s3 sync app/frontend/out s3://${{ secrets.STAGING_S3_BUCKET }} \
            --delete \
            --cache-control "public, max-age=31536000, immutable" \
            --exclude "*.html" \
            --exclude "*.json"

          aws s3 sync app/frontend/out s3://${{ secrets.STAGING_S3_BUCKET }} \
            --delete \
            --cache-control "public, max-age=0, must-revalidate" \
            --exclude "*" \
            --include "*.html" \
            --include "*.json"

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.STAGING_CLOUDFRONT_ID }} \
            --paths "/*"

  deploy-production:
    name: Deploy to Production
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://niigata-kaigo.example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: app/frontend/package-lock.json

      - name: Install dependencies
        run: npm ci
        working-directory: app/frontend

      - name: Build for production
        run: npm run build
        working-directory: app/frontend
        env:
          NODE_ENV: production
          NEXT_PUBLIC_API_URL: ${{ secrets.PROD_API_URL }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_PROD }}
          aws-region: ap-northeast-1

      - name: Deploy to S3
        run: |
          aws s3 sync app/frontend/out s3://${{ secrets.PROD_S3_BUCKET }} \
            --delete \
            --cache-control "public, max-age=31536000, immutable" \
            --exclude "*.html" \
            --exclude "*.json"

          aws s3 sync app/frontend/out s3://${{ secrets.PROD_S3_BUCKET }} \
            --delete \
            --cache-control "public, max-age=0, must-revalidate" \
            --exclude "*" \
            --include "*.html" \
            --include "*.json"

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.PROD_CLOUDFRONT_ID }} \
            --paths "/*"
```

---

## ワークフロー2: Backend CI/CD

### ファイルパス

`.github/workflows/backend-deploy.yml`

### ワークフロー定義

```yaml
name: Backend CI/CD

on:
  push:
    branches:
      - develop
      - main
    paths:
      - 'app/backend/**'
      - '.github/workflows/backend-deploy.yml'

permissions:
  id-token: write
  contents: read

env:
  DOTNET_VERSION: '9.0.x'
  ECR_REGISTRY: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
  ECR_REPOSITORY: niigata-kaigo-backend

jobs:
  test:
    name: Test Backend
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app/backend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --configuration Release --no-restore

      - name: Run tests
        run: dotnet test --no-build --verbosity normal --collect:"XPlat Code Coverage"

      - name: Upload coverage reports
        uses: codecov/codecov-action@v4
        with:
          directory: app/backend/tests/TestResults

  build-and-push:
    name: Build and Push Docker Image
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_SHARED }}
          aws-region: ap-northeast-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker image
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }} \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:latest \
            -f app/backend/Dockerfile \
            app/backend

      - name: Scan Docker image for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Push Docker image to ECR
        run: |
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }}
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

  deploy-staging:
    name: Deploy to Staging ECS
    needs: build-and-push
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://api-staging.niigata-kaigo.example.com

    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_STAGING }}
          aws-region: ap-northeast-1

      - name: Update ECS task definition
        run: |
          TASK_DEFINITION=$(aws ecs describe-task-definition \
            --task-definition niigata-kaigo-staging-backend \
            --query 'taskDefinition' \
            --output json)

          NEW_TASK_DEF=$(echo $TASK_DEFINITION | jq --arg IMAGE "$ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }}" \
            '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

          echo $NEW_TASK_DEF > task-def.json

      - name: Register new task definition
        id: register-task-def
        run: |
          NEW_TASK_ARN=$(aws ecs register-task-definition \
            --cli-input-json file://task-def.json \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
          echo "task_arn=$NEW_TASK_ARN" >> $GITHUB_OUTPUT

      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster niigata-kaigo-staging-cluster \
            --service niigata-kaigo-staging-backend-service \
            --task-definition ${{ steps.register-task-def.outputs.task_arn }} \
            --force-new-deployment

      - name: Wait for service stability
        run: |
          aws ecs wait services-stable \
            --cluster niigata-kaigo-staging-cluster \
            --services niigata-kaigo-staging-backend-service

  deploy-production:
    name: Deploy to Production ECS (Blue/Green)
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://api.niigata-kaigo.example.com

    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_PROD }}
          aws-region: ap-northeast-1

      - name: Update ECS task definition
        run: |
          TASK_DEFINITION=$(aws ecs describe-task-definition \
            --task-definition niigata-kaigo-prod-backend \
            --query 'taskDefinition' \
            --output json)

          NEW_TASK_DEF=$(echo $TASK_DEFINITION | jq --arg IMAGE "$ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }}" \
            '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

          echo $NEW_TASK_DEF > task-def.json

      - name: Deploy to ECS with Blue/Green
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: task-def.json
          service: niigata-kaigo-prod-backend-service
          cluster: niigata-kaigo-prod-cluster
          wait-for-service-stability: true
          codedeploy-appspec: appspec.yaml
          codedeploy-application: niigata-kaigo-prod-deploy
          codedeploy-deployment-group: niigata-kaigo-prod-backend-dg
```

---

## ワークフロー3: Infrastructure CI/CD

### ファイルパス

`.github/workflows/infra-deploy.yml`

### ワークフロー定義

```yaml
name: Infrastructure CI/CD

on:
  push:
    branches:
      - develop
      - main
    paths:
      - 'infra/cloudformation/**'
      - '.github/workflows/infra-deploy.yml'

permissions:
  id-token: write
  contents: read

jobs:
  validate:
    name: Validate CloudFormation Templates
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install cfn-lint
        run: pip install cfn-lint

      - name: Run cfn-lint
        run: |
          cfn-lint infra/cloudformation/templates/*.yaml

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_SHARED }}
          aws-region: ap-northeast-1

      - name: Validate CloudFormation templates
        run: |
          for template in infra/cloudformation/templates/*.yaml; do
            echo "Validating $template"
            aws cloudformation validate-template --template-body file://$template
          done

  deploy-staging:
    name: Deploy to Staging
    needs: validate
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment:
      name: staging-infra

    strategy:
      matrix:
        stack:
          - name: network
            template: infra/cloudformation/templates/network.yaml
            parameters: infra/cloudformation/parameters/staging/network.json
          - name: security
            template: infra/cloudformation/templates/security.yaml
            parameters: infra/cloudformation/parameters/staging/security.json
          - name: database
            template: infra/cloudformation/templates/database.yaml
            parameters: infra/cloudformation/parameters/staging/database.json
          - name: compute
            template: infra/cloudformation/templates/compute.yaml
            parameters: infra/cloudformation/parameters/staging/compute.json

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_STAGING }}
          aws-region: ap-northeast-1

      - name: Create Change Set
        id: create-changeset
        run: |
          STACK_NAME="niigata-kaigo-staging-${{ matrix.stack.name }}"
          CHANGESET_NAME="deploy-${{ github.sha }}"

          aws cloudformation create-change-set \
            --stack-name $STACK_NAME \
            --change-set-name $CHANGESET_NAME \
            --template-body file://${{ matrix.stack.template }} \
            --parameters file://${{ matrix.stack.parameters }} \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            || echo "Stack does not exist, will be created"

          echo "stack_name=$STACK_NAME" >> $GITHUB_OUTPUT
          echo "changeset_name=$CHANGESET_NAME" >> $GITHUB_OUTPUT

      - name: Wait for Change Set creation
        run: |
          aws cloudformation wait change-set-create-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      - name: Describe Change Set
        run: |
          aws cloudformation describe-change-set \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      - name: Execute Change Set
        run: |
          aws cloudformation execute-change-set \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      - name: Wait for stack update
        run: |
          aws cloudformation wait stack-update-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            || aws cloudformation wait stack-create-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }}

  deploy-production:
    name: Deploy to Production
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production-infra

    strategy:
      matrix:
        stack:
          - name: network
            template: infra/cloudformation/templates/network.yaml
            parameters: infra/cloudformation/parameters/prod/network.json
          - name: security
            template: infra/cloudformation/templates/security.yaml
            parameters: infra/cloudformation/parameters/prod/security.json
          - name: database
            template: infra/cloudformation/templates/database.yaml
            parameters: infra/cloudformation/parameters/prod/database.json
          - name: compute
            template: infra/cloudformation/templates/compute.yaml
            parameters: infra/cloudformation/parameters/prod/compute.json

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_PROD }}
          aws-region: ap-northeast-1

      - name: Create Change Set
        id: create-changeset
        run: |
          STACK_NAME="niigata-kaigo-prod-${{ matrix.stack.name }}"
          CHANGESET_NAME="deploy-${{ github.sha }}"

          aws cloudformation create-change-set \
            --stack-name $STACK_NAME \
            --change-set-name $CHANGESET_NAME \
            --template-body file://${{ matrix.stack.template }} \
            --parameters file://${{ matrix.stack.parameters }} \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            || echo "Stack does not exist, will be created"

          echo "stack_name=$STACK_NAME" >> $GITHUB_OUTPUT
          echo "changeset_name=$CHANGESET_NAME" >> $GITHUB_OUTPUT

      - name: Wait for Change Set creation
        run: |
          aws cloudformation wait change-set-create-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      - name: Describe Change Set
        run: |
          aws cloudformation describe-change-set \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      # 本番環境では手動承認が必要（GitHub Environment Protection Rules で設定）
      # この時点で承認待ちとなり、承認されたら次のステップへ進む

      - name: Execute Change Set
        run: |
          aws cloudformation execute-change-set \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --change-set-name ${{ steps.create-changeset.outputs.changeset_name }}

      - name: Wait for stack update
        run: |
          aws cloudformation wait stack-update-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            || aws cloudformation wait stack-create-complete \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }}

      - name: Run drift detection
        run: |
          DRIFT_ID=$(aws cloudformation detect-stack-drift \
            --stack-name ${{ steps.create-changeset.outputs.stack_name }} \
            --query 'StackDriftDetectionId' \
            --output text)

          aws cloudformation wait stack-drift-detection-complete \
            --stack-drift-detection-id $DRIFT_ID

          aws cloudformation describe-stack-drift-detection-status \
            --stack-drift-detection-id $DRIFT_ID
```

---

## GitHub Secrets 設定

### 必須シークレット

| シークレット名 | 説明 | 例 |
|-------------|------|---|
| `AWS_ROLE_STAGING` | ステージング環境IAMロールARN | `arn:aws:iam::111111111111:role/GitHubActionsDeployRole` |
| `AWS_ROLE_PROD` | 本番環境IAMロールARN | `arn:aws:iam::222222222222:role/GitHubActionsDeployRole` |
| `AWS_ROLE_SHARED` | 共有リソース用IAMロールARN | `arn:aws:iam::333333333333:role/GitHubActionsSharedRole` |
| `STAGING_API_URL` | ステージングAPI URL | `https://api-staging.example.com` |
| `PROD_API_URL` | 本番API URL | `https://api.example.com` |
| `STAGING_S3_BUCKET` | ステージングS3バケット名 | `niigata-kaigo-staging-frontend` |
| `PROD_S3_BUCKET` | 本番S3バケット名 | `niigata-kaigo-prod-frontend` |
| `STAGING_CLOUDFRONT_ID` | ステージングCloudFront ID | `E1234567890ABC` |
| `PROD_CLOUDFRONT_ID` | 本番CloudFront ID | `E0987654321XYZ` |

---

## Environment Protection Rules（本番環境）

### GitHub Settings → Environments → production

```yaml
Protection rules:
  - ✅ Required reviewers: 1名以上
  - ✅ Wait timer: 0 minutes（即座に承認可能）
  - ❌ Deployment branches: main のみ許可
```

これにより、本番デプロイ時に手動承認が必要になります。

---

## セキュリティスキャン

### 1. コンテナイメージスキャン（Trivy）

```yaml
- name: Scan Docker image for vulnerabilities
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
```

### 2. 依存関係スキャン（Dependabot）

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  # Frontend dependencies
  - package-ecosystem: "npm"
    directory: "/app/frontend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # Backend dependencies
  - package-ecosystem: "nuget"
    directory: "/app/backend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## ロールバック手順

### Frontend（S3 + CloudFront）

```bash
# S3バケットのバージョニングを利用
aws s3api list-object-versions \
  --bucket niigata-kaigo-prod-frontend \
  --prefix index.html

# 特定バージョンに復元
aws s3api copy-object \
  --bucket niigata-kaigo-prod-frontend \
  --copy-source niigata-kaigo-prod-frontend/index.html?versionId=<version-id> \
  --key index.html

# CloudFrontキャッシュ無効化
aws cloudfront create-invalidation \
  --distribution-id E0987654321XYZ \
  --paths "/*"
```

### Backend（ECS）

```bash
# 以前のタスク定義を取得
aws ecs describe-services \
  --cluster niigata-kaigo-prod-cluster \
  --services niigata-kaigo-prod-backend-service \
  --query 'services[0].deployments'

# 以前のタスク定義でサービス更新
aws ecs update-service \
  --cluster niigata-kaigo-prod-cluster \
  --service niigata-kaigo-prod-backend-service \
  --task-definition niigata-kaigo-prod-backend:123 \
  --force-new-deployment
```

### Infrastructure（CloudFormation）

```bash
# 以前のテンプレートで Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name rollback-to-previous \
  --template-body file://network-v1.2.0.yaml \
  --parameters file://parameters-prod.json

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name rollback-to-previous
```

---

## モニタリングとアラート

### CloudWatch Logs 統合

```yaml
- name: Send deployment notification
  if: always()
  run: |
    aws sns publish \
      --topic-arn arn:aws:sns:ap-northeast-1:123456789012:niigata-kaigo-deploy-notifications \
      --subject "Deployment ${{ job.status }}: ${{ github.ref }}" \
      --message "Deployment finished with status: ${{ job.status }}"
```

---

## トラブルシューティング

### ワークフローが失敗した場合

1. **GitHub Actions のログを確認**
   - Actionsタブ → 失敗したワークフロー → ログ確認

2. **AWS CloudWatch Logsを確認**
   - ECSタスクログ
   - CloudFormationイベント

3. **ロールバック実施**
   - 上記「ロールバック手順」参照

---

## 参照

- `docs/02_設計/基本設計/10_CICD/ブランチ戦略.md` - ブランチ戦略
- `docs/02_設計/基本設計/10_CICD/IaC戦略.md` - IaC戦略
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Actions for GitHub](https://github.com/aws-actions)

---

**作成日**: 2025-11-07
**作成者**: Claude (architect サブエージェント)
**レビュー状態**: Draft
