output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "db_private_subnet_ids" {
  description = "Database private subnet IDs"
  value       = module.vpc.db_private_subnet_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = module.vpc.public_route_table_id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = module.vpc.private_route_table_ids
}

output "default_security_group_id" {
  description = "Default security group ID"
  value       = module.vpc.default_security_group_id
}

output "availability_zones" {
  description = "Availability zones"
  value       = module.vpc.availability_zones
}

output "db_private_route_table_id" {
  description = "Database private route table ID"
  value       = module.vpc.db_private_route_table_id
}
