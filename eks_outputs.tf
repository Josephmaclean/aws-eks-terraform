output "eks" {
  description = "EKS, bastion, Argo CD, and Karpenter outputs for downstream consumers."
  value = {
    cluster_name                          = module.eks.cluster_name
    cluster_endpoint                      = module.eks.cluster_endpoint
    cluster_security_group_id             = module.eks.cluster_security_group_id
    kubectl_update_kubeconfig_command     = "aws eks update-kubeconfig --region ${var.aws_region} --profile ${var.aws_profile} --name ${module.eks.cluster_name}"
    kubectl_test_command                  = "kubectl get nodes"
    primary_node_group_arn                = module.eks.primary_node_group_arn
    ml_node_group_arn                     = module.eks.ml_node_group_arn
    karpenter_controller_role_arn         = module.eks.karpenter_controller_role_arn
    karpenter_node_role_name              = module.eks.karpenter_node_role_name
    karpenter_interruption_queue_name     = module.eks.karpenter_interruption_queue_name
    aws_load_balancer_controller_role_arn = module.eks.aws_load_balancer_controller_role_arn
    bastion_instance_id                   = var.enable_bastion ? module.bastion[0].instance_id : null
    bastion_role_arn                      = var.enable_bastion ? module.bastion[0].role_arn : null
    bastion_security_group_id             = var.enable_bastion ? module.bastion[0].security_group_id : null
    bastion_ssm_start_session_command     = var.enable_bastion ? "aws ssm start-session --region ${var.aws_region} --profile ${var.aws_profile} --target ${module.bastion[0].instance_id}" : null
    bastion_kubeconfig_command            = var.enable_bastion ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}" : null
    argocd_namespace                      = var.enable_argocd ? module.argocd[0].namespace : null
    argocd_release_name                   = var.enable_argocd ? module.argocd[0].release_name : null
    bastion_bootstrap_association_id      = local.enable_bastion_bootstrap ? aws_ssm_association.argocd_bootstrap[0].association_id : null
    argocd_bootstrap_association_id       = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? aws_ssm_association.argocd_bootstrap[0].association_id : null
    argocd_root_app_name                  = var.argocd_root_app_name
  }
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

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "kubectl_update_kubeconfig_command" {
  description = "Command to configure local kubectl access to this EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --profile ${var.aws_profile} --name ${module.eks.cluster_name}"
}

output "kubectl_test_command" {
  description = "Command to test local kubectl access after kubeconfig is updated."
  value       = "kubectl get nodes"
}

output "bastion_instance_id" {
  description = "Instance ID of the private SSM bastion/admin host."
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}

output "bastion_role_arn" {
  description = "IAM role ARN used by the private SSM bastion/admin host."
  value       = var.enable_bastion ? module.bastion[0].role_arn : null
}

output "bastion_security_group_id" {
  description = "Security group ID used by the private SSM bastion/admin host."
  value       = var.enable_bastion ? module.bastion[0].security_group_id : null
}

output "bastion_ssm_start_session_command" {
  description = "Command to start an SSM session on the bastion host."
  value       = var.enable_bastion ? "aws ssm start-session --region ${var.aws_region} --profile ${var.aws_profile} --target ${module.bastion[0].instance_id}" : null
}

output "bastion_kubeconfig_command" {
  description = "Command to run on the bastion host to configure kubectl."
  value       = var.enable_bastion ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}" : null
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

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN used by AWS Load Balancer Controller."
  value       = module.eks.aws_load_balancer_controller_role_arn
}

output "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  value       = var.enable_argocd ? module.argocd[0].namespace : null
}

output "argocd_release_name" {
  description = "Helm release name for Argo CD."
  value       = var.enable_argocd ? module.argocd[0].release_name : null
}

output "argocd_bastion_bootstrap_association_id" {
  description = "SSM association ID for the bastion-based Argo CD bootstrap."
  value       = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? aws_ssm_association.argocd_bootstrap[0].association_id : null
}

output "bastion_bootstrap_association_id" {
  description = "SSM association ID for the bastion-based EKS add-on bootstrap."
  value       = local.enable_bastion_bootstrap ? aws_ssm_association.argocd_bootstrap[0].association_id : null
}

output "argocd_root_app_name" {
  description = "Name of the Argo CD root Application, when root app bootstrap is configured."
  value       = var.argocd_root_app_name
}
