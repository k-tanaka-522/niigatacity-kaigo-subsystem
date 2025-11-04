# VPC Module - Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = try(aws_internet_gateway.main[0].id, "")
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidrs" {
  description = "List of private app subnet CIDR blocks"
  value       = aws_subnet.private_app[*].cidr_block
}

output "private_db_subnet_ids" {
  description = "List of private DB subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "private_db_subnet_cidrs" {
  description = "List of private DB subnet CIDR blocks"
  value       = aws_subnet.private_db[*].cidr_block
}

output "private_cache_subnet_ids" {
  description = "List of private cache subnet IDs"
  value       = aws_subnet.private_cache[*].id
}

output "tgw_attachment_subnet_ids" {
  description = "List of Transit Gateway attachment subnet IDs"
  value       = aws_subnet.tgw_attachment[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_eips" {
  description = "List of NAT Gateway Elastic IPs"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = try(aws_route_table.public[0].id, "")
}

output "private_app_route_table_ids" {
  description = "List of private app route table IDs"
  value       = aws_route_table.private_app[*].id
}

output "private_db_route_table_id" {
  description = "Private DB route table ID"
  value       = try(aws_route_table.private_db[0].id, "")
}

output "s3_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = try(aws_vpc_endpoint.s3[0].id, "")
}

output "dynamodb_endpoint_id" {
  description = "DynamoDB VPC Endpoint ID"
  value       = try(aws_vpc_endpoint.dynamodb[0].id, "")
}
