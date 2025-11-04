# Terraform IaC設計書 - 新潟市介護保険事業所システム

## ドキュメント管理情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | Terraform IaC設計書 |
| バージョン | 1.0.0 |
| 作成日 | 2025-11-04 |
| 最終更新日 | 2025-11-04 |
| ステータス | Draft |
| 前提ドキュメント | [AWS詳細設計書](01_aws_detailed_design.md) |

---

## 目次

1. [Terraform構成概要](#1-terraform構成概要)
2. [ディレクトリ構造](#2-ディレクトリ構造)
3. [State管理戦略](#3-state管理戦略)
4. [モジュール設計](#4-モジュール設計)
5. [環境管理戦略](#5-環境管理戦略)
6. [変数管理](#6-変数管理)
7. [CI/CD統合](#7-cicd統合)
8. [セキュリティベストプラクティス](#8-セキュリティベストプラクティス)

---

## 1. Terraform構成概要

### 1.1 採用理由

| 項目 | 理由 |
|-----|------|
| マルチアカウント対応 | AWS Organizations配下の複数アカウントを統一的に管理 |
| モジュール化 | 再利用可能なモジュール設計による保守性向上 |
| State管理 | S3 + DynamoDBによる安全なState管理とロック機構 |
| エコシステム | 豊富なProviderとコミュニティサポート |
| CI/CD統合 | GitHub Actionsとの親和性が高い |
| Drift検出 | terraform planによるドリフト検出が容易 |

### 1.2 Terraformバージョン戦略

| 項目 | 値 | 説明 |
|-----|-----|-----|
| Terraformバージョン | >= 1.6.0, < 2.0.0 | 1.6系を使用、2.0未満に固定 |
| AWS Provider | ~> 5.0 | 5.x系の最新を自動取得 |
| バージョン固定方法 | .terraform-version | tfenvで管理 |
| アップグレード方針 | 四半期ごとに検討 | セキュリティパッチは即座に適用 |

### 1.3 アカウント別責務

| アカウント | Terraform管理対象 | 責務 |
|----------|---------------|-----|
| management-account | AWS Organizations, SCPs, Billing | 組織全体の管理 |
| common-account | VPC, TGW, Direct Connect, Network Firewall | 共通ネットワークインフラ |
| prod-app-account | ECS, RDS, ElastiCache, ALB, S3 | 本番アプリケーションリソース |
| staging-account | ECS, RDS, ALB, S3 (縮小版) | ステージング環境 |
| operations-account | CloudWatch Logs集約, Lambda, Backup | 運用・監視リソース |
| security-account | Security Hub, GuardDuty, IAM IC | セキュリティ管理 |
| audit-account | CloudTrail, Config, S3 (ログ保管) | 監査ログ保管 |

---

## 2. ディレクトリ構造

### 2.1 全体構造

```
infra/terraform/
├── README.md                           # Terraform使用方法
├── .terraform-version                  # tfenvバージョン指定
├── backend-configs/                    # Backend設定ファイル
│   ├── common.hcl
│   ├── prod.hcl
│   ├── staging.hcl
│   └── operations.hcl
│
├── modules/                            # 再利用可能なモジュール
│   ├── networking/                     # ネットワークモジュール
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── transit-gateway/
│   │   ├── direct-connect/
│   │   └── route53/
│   │
│   ├── security/                       # セキュリティモジュール
│   │   ├── security-groups/
│   │   ├── waf/
│   │   ├── network-firewall/
│   │   ├── kms/
│   │   └── iam-roles/
│   │
│   ├── compute/                        # コンピューティングモジュール
│   │   ├── ecs-cluster/
│   │   ├── ecs-service/
│   │   ├── alb/
│   │   └── ecr/
│   │
│   ├── database/                       # データベースモジュール
│   │   ├── rds-aurora/
│   │   ├── elasticache/
│   │   └── rds-proxy/
│   │
│   ├── storage/                        # ストレージモジュール
│   │   ├── s3-bucket/
│   │   └── s3-replication/
│   │
│   └── monitoring/                     # 監視モジュール
│       ├── cloudwatch-alarms/
│       ├── cloudwatch-logs/
│       ├── bedrock-lambda/
│       └── sns-topics/
│
└── environments/                       # 環境別設定
    ├── common/                         # 共通アカウント
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── versions.tf
    │
    ├── prod/                           # 本番アカウント
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── versions.tf
    │
    ├── staging/                        # ステージングアカウント
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── versions.tf
    │
    └── operations/                     # 運用アカウント
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── terraform.tfvars
        └── versions.tf
```

### 2.2 ファイル命名規則

| ファイル名 | 用途 | 必須 |
|----------|------|------|
| main.tf | リソース定義 | ◯ |
| variables.tf | 変数定義 | ◯ |
| outputs.tf | 出力定義 | ◯ |
| versions.tf | Terraformとプロバイダーバージョン指定 | ◯ |
| terraform.tfvars | 環境固有の変数値 | ◯ |
| locals.tf | ローカル変数定義 | △ |
| data.tf | Data Sources定義 | △ |
| README.md | モジュール/環境説明 | ◯ |

---

## 3. State管理戦略

### 3.1 State Backend構成

**S3 + DynamoDB構成:**

```
management-account (111111111111)
│
└── S3 Bucket: terraform-state-niigatacity-kaigo
    ├── common/terraform.tfstate
    ├── prod/terraform.tfstate
    ├── staging/terraform.tfstate
    └── operations/terraform.tfstate

    + DynamoDB Table: terraform-state-lock
      └── LockID (Partition Key)
```

### 3.2 Backend設定ファイル

**backend-configs/prod.hcl:**

```hcl
bucket         = "terraform-state-niigatacity-kaigo"
key            = "prod/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:ap-northeast-1:111111111111:key/terraform-state-key"
dynamodb_table = "terraform-state-lock"
```

**backend-configs/common.hcl:**

```hcl
bucket         = "terraform-state-niigatacity-kaigo"
key            = "common/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:ap-northeast-1:111111111111:key/terraform-state-key"
dynamodb_table = "terraform-state-lock"
```

### 3.3 State管理ベストプラクティス

| 項目 | 設定 | 理由 |
|-----|------|------|
| 暗号化 | KMS (Customer Managed Key) | State内の機密情報保護 |
| バージョニング | 有効 | 誤削除・破損からの復旧 |
| ロック | DynamoDB | 同時実行防止 |
| アクセス制御 | IAMポリシー | 最小権限の原則 |
| State分離 | 環境ごとに別State | Blast Radius削減 |
| リモートState参照 | terraform_remote_state | 環境間のデータ共有 |

### 3.4 State初期化手順

```bash
# 1. S3バケットとDynamoDBテーブルを手動作成 (初回のみ)
aws s3 mb s3://terraform-state-niigatacity-kaigo --region ap-northeast-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-niigatacity-kaigo \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1

# 2. Terraform初期化
cd infra/terraform/environments/prod
terraform init -backend-config=../../backend-configs/prod.hcl
```

---

## 4. モジュール設計

### 4.1 モジュール設計原則

1. **Single Responsibility**: 1モジュール1責務
2. **Composable**: 組み合わせて使える設計
3. **Reusable**: 環境をまたいで再利用可能
4. **Versioned**: モジュールバージョン管理
5. **Documented**: README.mdで使用方法を明示

### 4.2 主要モジュール一覧

#### 4.2.1 VPCモジュール (modules/networking/vpc)

**入力変数:**

```hcl
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, staging, common)"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "List of private app subnet CIDR blocks"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "List of private DB subnet CIDR blocks"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost saving"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

**出力:**

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of private DB subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}
```

**使用例:**

```hcl
module "prod_vpc" {
  source = "../../modules/networking/vpc"

  vpc_cidr                  = "10.1.0.0/16"
  environment               = "prod"
  availability_zones        = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs       = ["10.1.1.0/24", "10.1.2.0/24"]
  private_app_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
  private_db_subnet_cidrs   = ["10.1.21.0/24", "10.1.22.0/24"]
  enable_nat_gateway        = true
  single_nat_gateway        = false

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

#### 4.2.2 ECS Serviceモジュール (modules/compute/ecs-service)

**入力変数:**

```hcl
variable "cluster_id" {
  description = "ECS Cluster ID"
  type        = string
}

variable "service_name" {
  description = "ECS Service name"
  type        = string
}

variable "task_definition_family" {
  description = "Task definition family name"
  type        = string
}

variable "container_definitions" {
  description = "Container definitions JSON"
  type        = string
}

variable "cpu" {
  description = "Task CPU units"
  type        = string
  default     = "2048"
}

variable "memory" {
  description = "Task memory (MiB)"
  type        = string
  default     = "4096"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "subnets" {
  description = "List of subnet IDs for task placement"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "container_name" {
  description = "Container name for load balancer"
  type        = string
}

variable "container_port" {
  description = "Container port for load balancer"
  type        = number
  default     = 8080
}

variable "enable_execute_command" {
  description = "Enable ECS Exec"
  type        = bool
  default     = true
}

variable "autoscaling_config" {
  description = "Auto Scaling configuration"
  type = object({
    min_capacity     = number
    max_capacity     = number
    cpu_threshold    = number
    memory_threshold = number
  })
  default = {
    min_capacity     = 2
    max_capacity     = 10
    cpu_threshold    = 70
    memory_threshold = 80
  }
}
```

**出力:**

```hcl
output "service_id" {
  description = "ECS Service ID"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}
```

#### 4.2.3 RDS Auroraモジュール (modules/database/rds-aurora)

**入力変数:**

```hcl
variable "cluster_identifier" {
  description = "RDS Cluster identifier"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.1"
}

variable "instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of DB instances"
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Initial database name"
  type        = string
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "pgadmin"
}

variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
}

variable "backup_retention_period" {
  description = "Backup retention period (days)"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "18:00-19:00"
}

variable "preferred_maintenance_window" {
  description = "Maintenance window (UTC)"
  type        = string
  default     = "sun:19:00-sun:20:00"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql"]
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period (days)"
  type        = number
  default     = 7
}
```

**出力:**

```hcl
output "cluster_endpoint" {
  description = "Cluster writer endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_id" {
  description = "Cluster identifier"
  value       = aws_rds_cluster.main.id
}

output "cluster_arn" {
  description = "Cluster ARN"
  value       = aws_rds_cluster.main.arn
}

output "instance_ids" {
  description = "List of instance identifiers"
  value       = aws_rds_cluster_instance.main[*].id
}
```

### 4.3 モジュールバージョニング戦略

**Git Tagsを使用したバージョン管理:**

```hcl
# リモートモジュール参照 (本番用)
module "vpc" {
  source = "git::https://github.com/k-tanaka-522/niigatacity-kaigo-subsystem.git//infra/terraform/modules/networking/vpc?ref=v1.0.0"

  # 変数設定
  vpc_cidr = "10.1.0.0/16"
  # ...
}

# ローカルモジュール参照 (開発用)
module "vpc" {
  source = "../../modules/networking/vpc"

  # 変数設定
  vpc_cidr = "10.1.0.0/16"
  # ...
}
```

**バージョン命名規則 (Semantic Versioning):**

- **Major (v1.0.0 → v2.0.0)**: 破壊的変更 (既存リソースの削除・再作成が必要)
- **Minor (v1.0.0 → v1.1.0)**: 新機能追加 (後方互換性あり)
- **Patch (v1.0.0 → v1.0.1)**: バグフィックス、ドキュメント修正

---

## 5. 環境管理戦略

### 5.1 環境別変数管理

**environments/prod/terraform.tfvars:**

```hcl
# 基本設定
environment = "prod"
aws_region  = "ap-northeast-1"
aws_account_id = "555555555555"

# VPC設定
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_app_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
private_db_subnet_cidrs  = ["10.1.21.0/24", "10.1.22.0/24"]

# ECS設定
ecs_task_cpu    = "2048"
ecs_task_memory = "4096"
ecs_desired_count = 2
ecs_autoscaling_min = 2
ecs_autoscaling_max = 10

# RDS設定
rds_instance_class = "db.r6g.large"
rds_instance_count = 2
rds_backup_retention_period = 7

# ElastiCache設定
redis_node_type = "cache.r6g.large"
redis_num_node_groups = 2
redis_replicas_per_node_group = 1

# タグ
tags = {
  Environment = "production"
  Project     = "niigatacity-kaigo"
  ManagedBy   = "Terraform"
  CostCenter  = "IT-Infrastructure"
}
```

**environments/staging/terraform.tfvars:**

```hcl
# 基本設定
environment = "staging"
aws_region  = "ap-northeast-1"
aws_account_id = "666666666666"

# VPC設定
vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
private_app_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]
private_db_subnet_cidrs  = ["10.2.21.0/24", "10.2.22.0/24"]

# ECS設定 (縮小版)
ecs_task_cpu    = "1024"
ecs_task_memory = "2048"
ecs_desired_count = 1
ecs_autoscaling_min = 1
ecs_autoscaling_max = 3

# RDS設定 (縮小版)
rds_instance_class = "db.t4g.medium"
rds_instance_count = 1
rds_backup_retention_period = 3

# ElastiCache設定 (なし)
redis_node_type = "cache.t4g.small"
redis_num_node_groups = 0  # ステージングではElastiCacheを使用しない

# タグ
tags = {
  Environment = "staging"
  Project     = "niigatacity-kaigo"
  ManagedBy   = "Terraform"
  CostCenter  = "IT-Infrastructure"
}
```

### 5.2 環境間のState参照

**本番環境からCommon VPCのTransit Gateway IDを参照:**

```hcl
# environments/prod/data.tf
data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "terraform-state-niigatacity-kaigo"
    key    = "common/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

# environments/prod/main.tf
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  transit_gateway_id = data.terraform_remote_state.common.outputs.transit_gateway_id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.tgw_attachment_subnet_ids

  tags = {
    Name = "prod-vpc-attachment"
  }
}
```

---

## 6. 変数管理

### 6.1 機密情報の管理

**Secrets Managerからの参照:**

```hcl
# Data sourceで取得
data "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id = "prod/db/master-password"
}

# RDSクラスター作成時に使用
resource "aws_rds_cluster" "main" {
  cluster_identifier = var.cluster_identifier
  master_username    = var.master_username
  master_password    = jsondecode(data.aws_secretsmanager_secret_version.rds_master_password.secret_string)["password"]

  # ...
}
```

**機密情報をTerraform管理外で事前作成:**

```bash
# RDSパスワードをSecrets Managerに作成 (Terraformの外で実行)
aws secretsmanager create-secret \
  --name prod/db/master-password \
  --secret-string '{"username":"pgadmin","password":"CHANGE_ME"}' \
  --region ap-northeast-1
```

### 6.2 変数バリデーション

```hcl
variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Environment must be prod, staging, or dev."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "rds_backup_retention_period" {
  description = "Backup retention period (days)"
  type        = number

  validation {
    condition     = var.rds_backup_retention_period >= 7 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention period must be between 7 and 35 days."
  }
}
```

---

## 7. CI/CD統合

### 7.1 GitHub Actions Workflow (Terraform Plan)

```.github/workflows/terraform-plan.yml```

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'infra/terraform/**'
      - '.github/workflows/terraform-plan.yml'

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [common, prod, staging, operations]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111111111111:role/GitHubActionsTerraformRole
          aws-region: ap-northeast-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform fmt -check -recursive

      - name: Terraform Init
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform init -backend-config=../../backend-configs/${{ matrix.environment }}.hcl

      - name: Terraform Validate
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform validate

      - name: Terraform Plan
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true

      - name: Comment Plan Result
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('infra/terraform/environments/${{ matrix.environment }}/tfplan.txt', 'utf8');

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan Result (${{ matrix.environment }})\n\`\`\`\n${plan}\n\`\`\``
            })
```

### 7.2 GitHub Actions Workflow (Terraform Apply)

```.github/workflows/terraform-apply.yml```

```yaml
name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - 'infra/terraform/**'

permissions:
  id-token: write
  contents: read

jobs:
  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: production
    strategy:
      matrix:
        environment: [common, prod, staging, operations]
      max-parallel: 1  # 順次実行

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111111111111:role/GitHubActionsTerraformRole
          aws-region: ap-northeast-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform init -backend-config=../../backend-configs/${{ matrix.environment }}.hcl

      - name: Terraform Apply
        working-directory: infra/terraform/environments/${{ matrix.environment }}
        run: terraform apply -auto-approve
```

### 7.3 pre-commit Hooks

```.pre-commit-config.yaml```

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_tfsec
        args:
          - --args=--minimum-severity=MEDIUM
```

---

## 8. セキュリティベストプラクティス

### 8.1 State Fileセキュリティ

| 項目 | 実装 |
|-----|------|
| 暗号化 | S3バケットレベル: AES-256, KMS暗号化有効 |
| アクセス制御 | IAMポリシーで最小権限、MFA必須 |
| バージョニング | 有効 (誤削除・破損からの復旧) |
| ロック | DynamoDB Table Lockで同時実行防止 |
| 監査 | CloudTrailでState変更ログ記録 |

### 8.2 機密情報管理

| 機密情報 | 管理方法 |
|---------|---------|
| RDSパスワード | Secrets Manager (Terraform管理外で事前作成) |
| APIキー | Secrets Manager (Terraform管理外で事前作成) |
| KMS暗号鍵 | Terraform管理 (鍵ポリシーで保護) |
| IAMロール | Terraform管理 (最小権限の原則) |

**禁止事項:**

- ❌ terraform.tfvarsに機密情報を直接記載
- ❌ default値に機密情報を設定
- ❌ outputで機密情報を出力 (sensitive = trueを使用)

**推奨事項:**

- ✅ Secrets Managerで機密情報を管理
- ✅ Data Sourceで動的に取得
- ✅ sensitive = true フラグで出力を隠蔽

```hcl
# 良い例
output "rds_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

# パスワードは出力しない、または...
output "rds_master_password_secret_arn" {
  description = "ARN of the secret containing RDS master password"
  value       = data.aws_secretsmanager_secret.rds_master_password.arn
  sensitive   = true
}
```

### 8.3 Drift検出と修正

**定期的なDrift検出 (GitHub Actions Scheduled):**

```yaml
name: Terraform Drift Detection

on:
  schedule:
    - cron: '0 0 * * *'  # 毎日0時 (UTC)

jobs:
  drift-detection:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [common, prod, staging, operations]

    steps:
      # ... (省略)

      - name: Terraform Plan (Drift Check)
        run: |
          terraform plan -detailed-exitcode
        continue-on-error: true
        id: plan

      - name: Notify if Drift Detected
        if: steps.plan.outcome == 'failure'
        run: |
          # SNS通知またはSlack通知
          echo "Drift detected in ${{ matrix.environment }}"
```

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|----------|------|---------|-------|
| 1.0.0 | 2025-11-04 | 初版作成 | Claude |

---

**次のドキュメント:** [CI/CD設計書](03_cicd_design.md)
