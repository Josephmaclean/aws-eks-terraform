output "vpc" {
  description = "VPC outputs for downstream consumers."
  value = {
    id                   = module.vpc.vpc_id
    cidr                 = module.vpc.vpc_cidr
    public_subnet_ids    = module.vpc.public_subnet_ids
    private_subnet_ids   = module.vpc.private_subnet_ids
    firewall_subnet_ids  = module.vpc.firewall_subnet_ids
    nat_gateway_id       = module.vpc.nat_gateway_id
    network_firewall_arn = module.vpc.network_firewall_arn
  }
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "firewall_subnet_ids" {
  description = "IDs of the AWS Network Firewall endpoint subnets."
  value       = module.vpc.firewall_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway used for private subnet egress."
  value       = module.vpc.nat_gateway_id
}

output "network_firewall_arn" {
  description = "ARN of the AWS Network Firewall."
  value       = module.vpc.network_firewall_arn
}
