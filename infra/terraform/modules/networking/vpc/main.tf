# VPC Module
# 新潟市介護保険事業所システム - VPCモジュール

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # AZ数を動的に取得
  az_count = length(var.availability_zones)

  # 共通タグ
  common_tags = merge(
    var.tags,
    {
      Module      = "vpc"
      Environment = var.environment
    }
  )
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc"
    }
  )
}

#------------------------------------------------------------------------------
# Internet Gateway
#------------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  count = var.create_public_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

#------------------------------------------------------------------------------
# Public Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.create_public_subnets ? local.az_count : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-public-subnet-${element(split("-", var.availability_zones[count.index]), 2)}"
      Type = "public"
    }
  )
}

#------------------------------------------------------------------------------
# Private App Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-app-subnet-${element(split("-", var.availability_zones[count.index]), 2)}"
      Type = "private-app"
    }
  )
}

#------------------------------------------------------------------------------
# Private DB Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-db-subnet-${element(split("-", var.availability_zones[count.index]), 2)}"
      Type = "private-db"
    }
  )
}

#------------------------------------------------------------------------------
# Private Cache Subnets (Optional)
#------------------------------------------------------------------------------

resource "aws_subnet" "private_cache" {
  count = length(var.private_cache_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cache_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-cache-subnet-${element(split("-", var.availability_zones[count.index]), 2)}"
      Type = "private-cache"
    }
  )
}

#------------------------------------------------------------------------------
# TGW Attachment Subnets (Optional)
#------------------------------------------------------------------------------

resource "aws_subnet" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.tgw_attachment_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-tgw-attachment-subnet-${element(split("-", var.availability_zones[count.index]), 2)}"
      Type = "tgw-attachment"
    }
  )
}

#------------------------------------------------------------------------------
# NAT Gateways
#------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-gateway-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

# Public Route Table
resource "aws_route_table" "public" {
  count = var.create_public_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-public-rt"
      Type = "public"
    }
  )
}

# Public Route - Internet Gateway
resource "aws_route" "public_internet" {
  count = var.create_public_subnets ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

# Public Subnet Association
resource "aws_route_table_association" "public" {
  count = var.create_public_subnets ? local.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private App Route Tables
resource "aws_route_table" "private_app" {
  count = var.single_nat_gateway ? 1 : local.az_count

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-app-rt-${count.index + 1}"
      Type = "private-app"
    }
  )
}

# Private App Route - NAT Gateway
resource "aws_route" "private_app_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Private App Subnet Association
resource "aws_route_table_association" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[var.single_nat_gateway ? 0 : count.index].id
}

# Private DB Route Table
resource "aws_route_table" "private_db" {
  count = length(var.private_db_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-db-rt"
      Type = "private-db"
    }
  )
}

# Private DB Subnet Association
resource "aws_route_table_association" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[0].id
}

# Private Cache Route Table
resource "aws_route_table" "private_cache" {
  count = length(var.private_cache_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-cache-rt"
      Type = "private-cache"
    }
  )
}

# Private Cache Subnet Association
resource "aws_route_table_association" "private_cache" {
  count = length(var.private_cache_subnet_cidrs)

  subnet_id      = aws_subnet.private_cache[count.index].id
  route_table_id = aws_route_table.private_cache[0].id
}

# TGW Attachment Route Table
resource "aws_route_table" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-tgw-attachment-rt"
      Type = "tgw-attachment"
    }
  )
}

# TGW Attachment Subnet Association
resource "aws_route_table_association" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs)

  subnet_id      = aws_subnet.tgw_attachment[count.index].id
  route_table_id = aws_route_table.tgw_attachment[0].id
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.main.id
  traffic_type    = var.flow_logs_traffic_type
  iam_role_arn    = var.flow_logs_role_arn
  log_destination = var.flow_logs_destination_arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc-flow-logs"
    }
  )
}

#------------------------------------------------------------------------------
# VPC Endpoints (Gateway)
#------------------------------------------------------------------------------

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = concat(
    aws_route_table.private_app[*].id,
    aws_route_table.private_db[*].id
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-s3-endpoint"
    }
  )
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"

  route_table_ids = concat(
    aws_route_table.private_app[*].id
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-dynamodb-endpoint"
    }
  )
}

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

data "aws_region" "current" {}
