# VPC Module

AWS VPCを作成するTerraformモジュールです。Multi-AZ構成に対応し、Public/Private App/Private DB/Private Cacheサブネット、NAT Gateway、VPC Endpoints等を含みます。

## 機能

- VPC作成
- インターネットゲートウェイ
- Public Subnets (ALB配置用)
- Private App Subnets (ECS Fargate配置用)
- Private DB Subnets (RDS配置用)
- Private Cache Subnets (ElastiCache配置用、オプション)
- TGW Attachment Subnets (Transit Gateway接続用、オプション)
- NAT Gateway (Single / Multi-AZ)
- VPC Flow Logs
- VPC Endpoints (S3, DynamoDB)

## 使用例

### 本番環境

```hcl
module "prod_vpc" {
  source = "../../modules/networking/vpc"

  vpc_cidr                  = "10.1.0.0/16"
  environment               = "prod"
  availability_zones        = ["ap-northeast-1a", "ap-northeast-1c"]

  create_public_subnets     = true
  public_subnet_cidrs       = ["10.1.1.0/24", "10.1.2.0/24"]

  private_app_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
  private_db_subnet_cidrs   = ["10.1.21.0/24", "10.1.22.0/24"]
  private_cache_subnet_cidrs = ["10.1.31.0/24", "10.1.32.0/24"]
  tgw_attachment_subnet_cidrs = ["10.1.41.0/24", "10.1.42.0/24"]

  enable_nat_gateway        = true
  single_nat_gateway        = false  # Multi-AZ (高可用性)

  enable_flow_logs          = true
  flow_logs_role_arn        = aws_iam_role.flow_logs.arn
  flow_logs_destination_arn = aws_cloudwatch_log_group.flow_logs.arn

  enable_s3_endpoint        = true
  enable_dynamodb_endpoint  = true

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

### ステージング環境 (コスト最適化)

```hcl
module "staging_vpc" {
  source = "../../modules/networking/vpc"

  vpc_cidr                  = "10.2.0.0/16"
  environment               = "staging"
  availability_zones        = ["ap-northeast-1a", "ap-northeast-1c"]

  public_subnet_cidrs       = ["10.2.1.0/24", "10.2.2.0/24"]
  private_app_subnet_cidrs  = ["10.2.11.0/24", "10.2.12.0/24"]
  private_db_subnet_cidrs   = ["10.2.21.0/24", "10.2.22.0/24"]

  enable_nat_gateway        = true
  single_nat_gateway        = true  # Single NAT (コスト削減)

  enable_flow_logs          = false  # コスト削減のため無効化

  tags = {
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_cidr | VPC CIDR block | `string` | n/a | yes |
| environment | Environment name (prod, staging, common) | `string` | n/a | yes |
| availability_zones | List of availability zones | `list(string)` | n/a | yes |
| create_public_subnets | Create public subnets and Internet Gateway | `bool` | `true` | no |
| public_subnet_cidrs | List of public subnet CIDR blocks | `list(string)` | `[]` | no |
| private_app_subnet_cidrs | List of private app subnet CIDR blocks | `list(string)` | n/a | yes |
| private_db_subnet_cidrs | List of private DB subnet CIDR blocks | `list(string)` | `[]` | no |
| private_cache_subnet_cidrs | List of private cache subnet CIDR blocks | `list(string)` | `[]` | no |
| tgw_attachment_subnet_cidrs | List of TGW attachment subnet CIDR blocks | `list(string)` | `[]` | no |
| enable_nat_gateway | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| single_nat_gateway | Use single NAT Gateway (cost saving) | `bool` | `false` | no |
| enable_dns_hostnames | Enable DNS hostnames in the VPC | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in the VPC | `bool` | `true` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |
| flow_logs_traffic_type | Traffic type for Flow Logs (ALL, ACCEPT, REJECT) | `string` | `"ALL"` | no |
| flow_logs_role_arn | IAM role ARN for Flow Logs | `string` | `""` | no |
| flow_logs_destination_arn | Destination ARN for Flow Logs | `string` | `""` | no |
| enable_s3_endpoint | Enable S3 VPC Gateway Endpoint | `bool` | `true` | no |
| enable_dynamodb_endpoint | Enable DynamoDB VPC Gateway Endpoint | `bool` | `true` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| vpc_arn | VPC ARN |
| internet_gateway_id | Internet Gateway ID |
| public_subnet_ids | List of public subnet IDs |
| private_app_subnet_ids | List of private app subnet IDs |
| private_db_subnet_ids | List of private DB subnet IDs |
| private_cache_subnet_ids | List of private cache subnet IDs |
| tgw_attachment_subnet_ids | List of TGW attachment subnet IDs |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_eips | List of NAT Gateway Elastic IPs |
| public_route_table_id | Public route table ID |
| private_app_route_table_ids | List of private app route table IDs |
| private_db_route_table_id | Private DB route table ID |
| s3_endpoint_id | S3 VPC Endpoint ID |
| dynamodb_endpoint_id | DynamoDB VPC Endpoint ID |

## サブネット設計

### 本番環境 (10.1.0.0/16)

| サブネット | CIDR | AZ | 用途 |
|----------|------|----|----|
| public-1a | 10.1.1.0/24 | ap-northeast-1a | ALB, NAT Gateway |
| public-1c | 10.1.2.0/24 | ap-northeast-1c | ALB, NAT Gateway |
| private-app-1a | 10.1.11.0/24 | ap-northeast-1a | ECS Fargate |
| private-app-1c | 10.1.12.0/24 | ap-northeast-1c | ECS Fargate |
| private-db-1a | 10.1.21.0/24 | ap-northeast-1a | RDS Primary |
| private-db-1c | 10.1.22.0/24 | ap-northeast-1c | RDS Standby |
| private-cache-1a | 10.1.31.0/24 | ap-northeast-1a | ElastiCache |
| private-cache-1c | 10.1.32.0/24 | ap-northeast-1c | ElastiCache |
| tgw-attachment-1a | 10.1.41.0/24 | ap-northeast-1a | Transit Gateway |
| tgw-attachment-1c | 10.1.42.0/24 | ap-northeast-1c | Transit Gateway |

## NAT Gateway戦略

### Multi-AZ (本番環境推奨)

- **高可用性**: 各AZにNAT Gatewayを配置
- **単一AZ障害の影響なし**
- **コスト**: 高 (NAT Gateway × 2 + データ転送料金)

```hcl
enable_nat_gateway = true
single_nat_gateway = false
```

### Single NAT (ステージング環境推奨)

- **コスト最適化**: 1つのNAT Gatewayのみ
- **単一AZ障害でアウトバウンド通信不可**
- **コスト**: 低 (NAT Gateway × 1 + データ転送料金)

```hcl
enable_nat_gateway = true
single_nat_gateway = true
```

## VPC Flow Logs

VPC内のネットワークトラフィックをキャプチャします。

### CloudWatch Logsへの出力

```hcl
enable_flow_logs          = true
flow_logs_traffic_type    = "ALL"  # ALL, ACCEPT, REJECT
flow_logs_role_arn        = aws_iam_role.flow_logs.arn
flow_logs_destination_arn = aws_cloudwatch_log_group.flow_logs.arn
```

### S3への出力

```hcl
enable_flow_logs          = true
flow_logs_traffic_type    = "ALL"
flow_logs_destination_arn = "arn:aws:s3:::vpc-flow-logs-bucket/prefix"
```

## VPC Endpoints

### S3 Gateway Endpoint

S3へのトラフィックがインターネットを経由せず、プライベート接続されます。

- **メリット**: データ転送料金削減、セキュリティ向上
- **コスト**: 無料

### DynamoDB Gateway Endpoint

DynamoDBへのプライベート接続を提供します。

- **コスト**: 無料

## ベストプラクティス

1. **Multi-AZ構成**: 最低2つのAZを使用
2. **サブネット分離**: Public/Private App/Private DBを明確に分離
3. **NAT Gateway冗長化**: 本番環境では各AZにNAT Gatewayを配置
4. **VPC Flow Logs有効化**: セキュリティ監査とトラブルシューティング
5. **VPC Endpoints活用**: S3/DynamoDBはGateway Endpointを使用

## トラブルシューティング

### NAT Gatewayが作成されない

```
Error: creating EC2 NAT Gateway: InvalidSubnetID.NotFound
```

**原因**: Public Subnetが存在しない、またはInternet Gatewayが未作成

**解決策**:
- `create_public_subnets = true` を設定
- `public_subnet_cidrs` を指定

### VPC Endpoint作成エラー

```
Error: creating VPC Endpoint: InvalidParameter
```

**原因**: Route Tableが存在しない

**解決策**:
- Private App SubnetまたはPrivate DB Subnetを先に作成

## ライセンス

このモジュールは新潟市介護保険事業所システムの一部であり、内部使用のみを目的としています。
