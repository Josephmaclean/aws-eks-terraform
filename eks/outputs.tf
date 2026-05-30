output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS control plane."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required by Kubernetes clients."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "primary_node_group_arn" {
  description = "ARN of the primary EKS managed node group."
  value       = aws_eks_node_group.primary.arn
}

output "ml_node_group_arn" {
  description = "ARN of the ML EKS managed node group."
  value       = aws_eks_node_group.ml.arn
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller service account."
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_name" {
  description = "IAM role name used by Karpenter-launched nodes."
  value       = aws_iam_role.karpenter_nodes.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling."
  value       = aws_sqs_queue.karpenter_interruption.name
}
