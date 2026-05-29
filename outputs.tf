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

output "eks_cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required by Kubernetes clients."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "primary_node_group_arn" {
  description = "ARN of the primary EKS managed node group."
  value       = module.eks.primary_node_group_arn
}

output "ml_node_group_arn" {
  description = "ARN of the ML EKS managed node group."
  value       = module.eks.ml_node_group_arn
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller service account."
  value       = module.eks.karpenter_controller_role_arn
}

output "karpenter_node_role_name" {
  description = "IAM role name used by Karpenter-launched nodes."
  value       = module.eks.karpenter_node_role_name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling."
  value       = module.eks.karpenter_interruption_queue_name
}
