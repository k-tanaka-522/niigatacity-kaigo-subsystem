# CloudFormation スタックのライフサイクル管理

**作成日**: 2025-11-09
**更新日**: 2025-11-09
**対象環境**: 本番（Production）、ステージング（Staging）

---

## 1. 目的

このドキュメントでは、CloudFormation スタックのライフサイクル（変更頻度）に基づく管理方針と運用ガイドラインを定義します。

**背景**:
- 変更頻度の異なるリソースを適切に分離
- 変更リスクの最小化
- デプロイ効率の向上
- 運用負荷の軽減

---

## 2. スタックのライフサイクル分類

### 2.1 ライフサイクルとは

**ライフサイクル**: リソースの変更頻度を表す指標

| ライフサイクル | 変更頻度 | 変更の性質 | スタック例 |
|-------------|--------|----------|-----------|
| **年単位** | 初回のみ、慎重に変更 | インフラ基盤 | 01-audit, 02-network |
| **月単位** | たまに変更 | データ層、セキュリティ | 03-security, 04-database, 05-storage |
| **週単位** | 定期的に変更 | コンピュートリソース | 06-compute-base |
| **日単位** | 頻繁に変更 | アプリケーション設定 | 07-compute-app |

### 2.2 新潟市プロジェクトのスタック分類

| スタック名 | ライフサイクル | 主要リソース | 変更の例 |
|-----------|--------------|------------|---------|
| **01-audit** | 年単位 | CloudTrail, AWS Config, GuardDuty | 監査設定の追加 |
| **02-network** | 年単位 | VPC, Subnets, NAT Gateway, Route Tables | サブネット追加 |
| **03-security** | 月単位 | WAF, Security Hub, KMS | WAFルール追加 |
| **04-database** | 月単位 | RDS MySQL, ElastiCache Redis | インスタンスサイズ変更 |
| **05-storage** | 月単位 | S3, CloudFront | バケット追加 |
| **06-compute-base** | 週単位 | ECS Cluster, ALB, ECR | Auto Scaling設定変更 |
| **07-compute-app** | 日単位 | ECS Task Definition, Service | Docker イメージ更新 |
| **08-monitoring** | 月単位 | CloudWatch, SNS | アラーム追加 |

---

## 3. ライフサイクル別の運用方針

### 3.1 年単位スタック（01-audit, 02-network）

**特徴**:
- 初回のみ作成、慎重に変更
- 変更時は全体への影響が大きい
- 他のスタックの依存元になる

**運用方針**:

| 項目 | 方針 |
|-----|------|
| デプロイ | 本番前に Staging で十分検証 |
| Change Set レビュー | 必須（複数人でレビュー） |
| 変更タイミング | メンテナンスウィンドウ |
| ロールバック準備 | 必須 |
| 影響範囲確認 | 全スタックへの影響を確認 |

**変更例**:

```bash
# 例: Subnet を追加する場合

# ステップ1: Staging で検証
./scripts/create-changeset.sh \
  niigata-kaigo-staging-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ2: Change Set を複数人でレビュー
./scripts/describe-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>

# ステップ3: Staging で実行
./scripts/execute-changeset.sh \
  niigata-kaigo-staging-network-stack \
  <changeset-name>

# ステップ4: Staging で動作確認（1週間）

# ステップ5: Production で実行（メンテナンスウィンドウ）
./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

### 3.2 月単位スタック（03-security, 04-database, 05-storage, 08-monitoring）

**特徴**:
- たまに変更
- データ層やセキュリティ設定
- 変更時は影響範囲を確認

**運用方針**:

| 項目 | 方針 |
|-----|------|
| デプロイ | Staging で検証後、Production へ |
| Change Set レビュー | 必須 |
| 変更タイミング | 営業時間外推奨 |
| ロールバック準備 | 推奨 |
| 影響範囲確認 | 関連スタックへの影響を確認 |

**変更例**:

```bash
# 例: RDS インスタンスサイズを変更

# ステップ1: parameters/staging.json を編集
{
  "ParameterKey": "DBInstanceClass",
  "ParameterValue": "db.t3.medium"  # db.t3.small から変更
}

# ステップ2: Staging で Change Set 作成・レビュー
./scripts/create-changeset.sh \
  niigata-kaigo-staging-database-stack \
  infra/cloudformation/stacks/04-database/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

# ステップ3: Staging で実行・検証（数日）

# ステップ4: Production で実行（営業時間外）
# parameters/production.json を同様に編集
./scripts/create-changeset.sh \
  niigata-kaigo-production-database-stack \
  infra/cloudformation/stacks/04-database/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

### 3.3 週単位スタック（06-compute-base）

**特徴**:
- 定期的に変更
- コンピュートリソースの設定
- Auto Scaling、ALB設定など

**運用方針**:

| 項目 | 方針 |
|-----|------|
| デプロイ | Staging で簡易検証後、Production へ |
| Change Set レビュー | 必須 |
| 変更タイミング | 営業時間内でも可（Blue/Green デプロイ） |
| ロールバック準備 | 推奨 |
| 影響範囲確認 | アプリケーション層への影響を確認 |

**変更例**:

```bash
# 例: Auto Scaling の最大台数を変更

# ステップ1: parameters/staging.json を編集
{
  "ParameterKey": "ECSServiceMaxCapacity",
  "ParameterValue": "10"  # 5 から変更
}

# ステップ2: Staging で Change Set 作成・実行
./scripts/create-changeset.sh \
  niigata-kaigo-staging-compute-base-stack \
  infra/cloudformation/stacks/06-compute-base/main.yaml \
  infra/cloudformation/parameters/staging.json \
  staging

./scripts/execute-changeset.sh \
  niigata-kaigo-staging-compute-base-stack \
  <changeset-name>

# ステップ3: 数時間後、Production で実行
# parameters/production.json を同様に編集
./scripts/create-changeset.sh \
  niigata-kaigo-production-compute-base-stack \
  infra/cloudformation/stacks/06-compute-base/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

### 3.4 日単位スタック（07-compute-app）

**特徴**:
- 頻繁に変更
- アプリケーションのデプロイ
- Docker イメージ更新、環境変数変更

**運用方針**:

| 項目 | 方針 |
|-----|------|
| デプロイ | CI/CD パイプラインで自動化 |
| Change Set レビュー | 軽量レビュー（自動テスト合格が前提） |
| 変更タイミング | 営業時間内でも可（Blue/Green デプロイ） |
| ロールバック準備 | 必須（自動ロールバック設定） |
| 影響範囲確認 | アプリケーションレベルのテストで確認 |

**変更例（CI/CD パイプライン）**:

```yaml
# .github/workflows/app-deploy.yml
name: Application Deployment

on:
  push:
    branches:
      - master
    paths:
      - 'app/**'

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker Image
        run: |
          docker build -t niigata-kaigo-backend:${{ github.sha }} app/backend

      - name: Push to ECR
        run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_URI>
          docker tag niigata-kaigo-backend:${{ github.sha }} <ECR_URI>/niigata-kaigo-backend:${{ github.sha }}
          docker push <ECR_URI>/niigata-kaigo-backend:${{ github.sha }}

      - name: Update ECS Task Definition
        run: |
          # parameters/staging.json の ECSTaskImageTag を更新
          jq '.[] |= if .ParameterKey == "ECSTaskImageTag" then .ParameterValue = "${{ github.sha }}" else . end' \
            infra/cloudformation/parameters/staging.json > /tmp/staging.json
          mv /tmp/staging.json infra/cloudformation/parameters/staging.json

      - name: Deploy to Staging
        run: |
          ./scripts/create-changeset.sh \
            niigata-kaigo-staging-compute-app-stack \
            infra/cloudformation/stacks/07-compute-app/main.yaml \
            infra/cloudformation/parameters/staging.json \
            staging

          CHANGESET_NAME=$(aws cloudformation list-change-sets \
            --stack-name niigata-kaigo-staging-compute-app-stack \
            --query 'Summaries[0].ChangeSetName' \
            --output text)

          echo "yes" | ./scripts/execute-changeset.sh \
            niigata-kaigo-staging-compute-app-stack \
            $CHANGESET_NAME

      - name: Run Smoke Tests
        run: |
          # Staging 環境でスモークテスト
          curl -f https://staging.niigata-kaigo.example.com/health || exit 1

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      # ... Production deployment (similar to staging)
```

---

## 4. スタック間の依存関係管理

### 4.1 依存関係の可視化

```
01-audit
  ↓
02-network ─────→ 03-security
  ↓               ↓
  ├──→ 04-database
  ├──→ 05-storage
  ↓               ↓
06-compute-base ───┘
  ↓
07-compute-app
  ↓
08-monitoring ←─────┘
```

### 4.2 デプロイ順序

**初回デプロイ順序**:

```
1. 01-audit（CloudTrail, AWS Config）
2. 02-network（VPC, Subnets）
3. 03-security（WAF, KMS）
4. 04-database（RDS, ElastiCache）
5. 05-storage（S3, CloudFront）
6. 06-compute-base（ECS Cluster, ALB）
7. 07-compute-app（ECS Task Definition, Service）
8. 08-monitoring（CloudWatch, SNS）
```

**理由**: 依存関係があるため、この順序でデプロイする必要がある

### 4.3 変更時の影響範囲

| 変更対象スタック | 影響を受ける可能性のあるスタック | 確認事項 |
|---------------|--------------------------|---------|
| 01-audit | なし（独立） | - |
| 02-network | 03, 04, 05, 06, 07, 08（全て） | VPC ID, Subnet IDs の Export が変わっていないか |
| 03-security | 06, 07 | Security Group の Export が変わっていないか |
| 04-database | 07 | RDS エンドポイントの Export が変わっていないか |
| 05-storage | 07 | S3 バケット名の Export が変わっていないか |
| 06-compute-base | 07 | ECS Cluster ARN, ALB Target Group ARN の Export が変わっていないか |
| 07-compute-app | なし（他のスタックに依存するが、他に影響しない） | - |
| 08-monitoring | なし（独立） | - |

---

## 5. 変更頻度別のベストプラクティス

### 5.1 年単位スタックのベストプラクティス

```yaml
# 良い例: VPC, Subnets を分ける
# templates/network/vpc-and-igw.yaml（変更ほぼなし）
# templates/network/subnets.yaml（たまに追加）

# 悪い例: VPC, Subnets を同じファイルに
# templates/network/vpc.yaml（Subnet 追加のたびに VPC に影響）
```

**理由**: Subnet 追加時に VPC リソースに影響しないようにする

### 5.2 月単位スタックのベストプラクティス

```yaml
# 良い例: RDS と ElastiCache を別ファイルに
# templates/database/rds-mysql.yaml
# templates/database/elasticache-redis.yaml

# 悪い例: RDS と ElastiCache を同じファイルに
# templates/database/database.yaml
```

**理由**: RDS のみ変更時に ElastiCache に影響しないようにする

### 5.3 週単位スタックのベストプラクティス

```yaml
# 良い例: ECS Cluster と Task Definition を分ける
# templates/compute/ecs-cluster.yaml（変更少）
# templates/compute/ecs-task-backend.yaml（変更多）

# 悪い例: ECS Cluster と Task Definition を同じファイルに
# templates/compute/ecs.yaml
```

**理由**: Task Definition 更新時に Cluster に影響しないようにする

### 5.4 日単位スタックのベストプラクティス

```yaml
# 良い例: Service 別に Task Definition を分ける
# templates/compute/ecs-task-backend.yaml
# templates/compute/ecs-task-frontend.yaml

# 悪い例: 全てのタスクを同じファイルに
# templates/compute/ecs-tasks.yaml
```

**理由**: Backend のみ更新時に Frontend に影響しないようにする

---

## 6. メンテナンスウィンドウ

### 6.1 メンテナンスウィンドウとは

**定義**: システム変更を実施する時間帯

| スタックライフサイクル | メンテナンスウィンドウ | 理由 |
|------------------|-------------------|------|
| 年単位 | 月1回（第3土曜日 2:00-5:00） | 影響大、慎重に実施 |
| 月単位 | 隔週（土曜日 2:00-4:00） | 影響中、営業時間外推奨 |
| 週単位 | 毎週（営業時間内でも可） | Blue/Green デプロイで影響小 |
| 日単位 | いつでも可 | CI/CD パイプラインで自動化 |

### 6.2 新潟市プロジェクトのメンテナンスウィンドウ

**通常メンテナンスウィンドウ**:
- 日時: 第3土曜日 2:00-5:00 JST
- 対象: 年単位、月単位スタック
- 通知: 1週間前にユーザーに通知

**緊急メンテナンスウィンドウ**:
- 日時: セキュリティパッチ適用時など
- 対象: 全スタック
- 通知: 24時間前にユーザーに通知

---

## 7. ロールバック戦略

### 7.1 ライフサイクル別ロールバック戦略

| ライフサイクル | ロールバック方法 | 準備事項 |
|-------------|---------------|---------|
| 年単位 | CloudFormation 自動ロールバック + 手動確認 | 前バージョンのバックアップ必須 |
| 月単位 | CloudFormation 自動ロールバック | Change Set レビューで事前確認 |
| 週単位 | CloudFormation 自動ロールバック | 前バージョンのイメージ保持 |
| 日単位 | ECS Blue/Green デプロイ（自動ロールバック） | ヘルスチェック設定必須 |

### 7.2 ロールバック手順

**年単位・月単位スタック**:

```bash
# 方法1: CloudFormation 自動ロールバック
./scripts/rollback.sh niigata-kaigo-production-network-stack

# 方法2: 前のバージョンの Change Set を再実行
# 前バージョンの git commit hash を確認
git log infra/cloudformation/stacks/02-network/main.yaml

# 前バージョンの Change Set を作成・実行
git checkout <previous-commit-hash>
./scripts/create-changeset.sh \
  niigata-kaigo-production-network-stack \
  infra/cloudformation/stacks/02-network/main.yaml \
  infra/cloudformation/parameters/production.json \
  production
```

**週単位・日単位スタック**:

```bash
# ECS Blue/Green デプロイ（自動ロールバック）
# ECS Service の DeploymentConfiguration で設定

Resources:
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 100
        DeploymentCircuitBreaker:
          Enable: true
          Rollback: true  # ヘルスチェック失敗時に自動ロールバック
```

---

## 8. モニタリングとアラート

### 8.1 スタック変更の監視

**CloudWatch Events でスタック変更を監視**:

```yaml
# templates/monitoring/eventbridge-rules.yaml
Resources:
  StackChangeEventRule:
    Type: AWS::Events::Rule
    Properties:
      Description: 'Notify on CloudFormation stack changes'
      EventPattern:
        source:
          - aws.cloudformation
        detail-type:
          - CloudFormation Stack Status Change
        detail:
          stack-name:
            - prefix: 'niigata-kaigo-production-'
      Targets:
        - Arn: !Ref SNSTopicForAlerts
          Id: CloudFormationStackChange
```

### 8.2 アラート通知例

**Slack 通知**:

```
🚀 [Production] Network Stack Update Started
   Stack: niigata-kaigo-production-network-stack
   Change Set: <changeset-name>
   Status: UPDATE_IN_PROGRESS
   Time: 2025-11-09 14:30:00 JST

✅ [Production] Network Stack Update Completed
   Stack: niigata-kaigo-production-network-stack
   Status: UPDATE_COMPLETE
   Duration: 15 minutes
   Time: 2025-11-09 14:45:00 JST
```

---

## 9. まとめ

### 9.1 ライフサイクル別の運用方針（再掲）

| ライフサイクル | 変更頻度 | デプロイタイミング | レビュー | ロールバック準備 |
|-------------|--------|----------------|---------|---------------|
| 年単位 | 初回のみ | メンテナンスウィンドウ | 複数人レビュー必須 | 必須 |
| 月単位 | たまに | 営業時間外推奨 | レビュー必須 | 推奨 |
| 週単位 | 定期的 | 営業時間内でも可 | レビュー必須 | 推奨 |
| 日単位 | 頻繁 | いつでも可 | 自動テスト | 自動ロールバック |

### 9.2 スタック分割の効果

**メリット**:
1. **変更リスクの最小化**: 変更頻度の異なるリソースを分離
2. **デプロイ効率の向上**: 頻繁に変更するスタックのみデプロイ
3. **運用負荷の軽減**: 変更影響範囲を限定
4. **並行作業の実現**: チームで異なるスタックを同時に変更可能

---

**関連ドキュメント**:
- [cloudformation_structure.md](./cloudformation_structure.md) - ファイル分割3原則とディレクトリ構造
- [deployment_strategy.md](./deployment_strategy.md) - デプロイ戦略と Change Sets 運用
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` - CloudFormation 技術標準
