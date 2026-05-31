module "eks" {
  source = "./eks"

  cluster_name                                      = var.cluster_name
  cluster_version                                   = var.cluster_version
  vpc_id                                            = module.vpc.vpc_id
  subnet_ids                                        = module.vpc.private_subnet_ids
  cluster_endpoint_public_access                    = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs              = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access                   = var.cluster_endpoint_private_access
  primary_node_group_instance_types                 = var.primary_node_group_instance_types
  primary_node_group_min_size                       = var.primary_node_group_min_size
  primary_node_group_desired_size                   = var.primary_node_group_desired_size
  primary_node_group_max_size                       = var.primary_node_group_max_size
  ml_node_group_instance_types                      = var.ml_node_group_instance_types
  ml_node_group_min_size                            = var.ml_node_group_min_size
  ml_node_group_desired_size                        = var.ml_node_group_desired_size
  ml_node_group_max_size                            = var.ml_node_group_max_size
  ml_node_group_ami_type                            = var.ml_node_group_ami_type
  karpenter_namespace                               = var.karpenter_namespace
  karpenter_service_account_name                    = var.karpenter_service_account_name
  karpenter_interruption_queue_retention            = var.karpenter_interruption_queue_retention
  aws_load_balancer_controller_namespace            = var.aws_load_balancer_controller_namespace
  aws_load_balancer_controller_service_account_name = var.aws_load_balancer_controller_service_account_name

  depends_on = [terraform_data.vpc_final_destroy_cleanup]
}

module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./bastion"

  name            = var.name
  vpc_id          = module.vpc.vpc_id
  subnet_id       = module.vpc.private_subnet_ids[0]
  instance_type   = var.bastion_instance_type
  kubectl_version = var.kubectl_version
  cluster_name    = module.eks.cluster_name
  aws_region      = var.aws_region
  secret_arns     = var.enable_bastion_argocd_bootstrap ? [data.aws_secretsmanager_secret.argocd_repo[0].arn] : [var.argocd_repo_secret_arn]

  depends_on = [module.eks]
}

module "argocd" {
  count  = var.enable_argocd ? 1 : 0
  source = "./argocd"

  namespace           = var.argocd_namespace
  chart_version       = var.argocd_chart_version
  server_service_type = var.argocd_server_service_type
  values              = var.argocd_values

  depends_on = [module.eks]
}
