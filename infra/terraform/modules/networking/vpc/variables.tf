# VPC Module - Variables

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "environment" {
  description = "Environment name (prod, staging, common)"
  type        = string

  validation {
    condition     = contains(["prod", "staging", "common", "operations"], var.environment)
    error_message = "Environment must be one of: prod, staging, common, operations."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified for high availability."
  }
}

variable "create_public_subnets" {
  description = "Create public subnets and Internet Gateway"
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "private_app_subnet_cidrs" {
  description = "List of private app subnet CIDR blocks"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "List of private DB subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "private_cache_subnet_cidrs" {
  description = "List of private cache subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "tgw_attachment_subnet_cidrs" {
  description = "List of Transit Gateway attachment subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all private subnets (cost saving)"
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

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_traffic_type" {
  description = "Traffic type for Flow Logs (ALL, ACCEPT, REJECT)"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "Flow logs traffic type must be ALL, ACCEPT, or REJECT."
  }
}

variable "flow_logs_role_arn" {
  description = "IAM role ARN for Flow Logs"
  type        = string
  default     = ""
}

variable "flow_logs_destination_arn" {
  description = "Destination ARN for Flow Logs (CloudWatch Logs or S3)"
  type        = string
  default     = ""
}

variable "enable_s3_endpoint" {
  description = "Enable S3 VPC Gateway Endpoint"
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Enable DynamoDB VPC Gateway Endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
