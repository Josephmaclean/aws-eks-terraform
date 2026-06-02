data "aws_partition" "current" {}

locals {
  argocd_repo_secret_id = var.argocd_repo_secret_id != "" ? var.argocd_repo_secret_id : "${var.name}/github/repo"
  enable_bastion_bootstrap = var.enable_bastion && (
    var.enable_bastion_argocd_bootstrap ||
    var.enable_bastion_karpenter_bootstrap ||
    var.enable_bastion_aws_load_balancer_controller_bootstrap
  )
}

module "vpc" {
  source = "./modules/vpc_components"

  name                  = var.name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  karpenter_discovery   = var.cluster_name
  public_subnet_cidrs   = var.public_subnet_cidrs
  firewall_subnet_cidrs = var.firewall_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

module "eks" {
  source = "./modules/eks_components"

  cluster_name                                          = var.cluster_name
  cluster_version                                       = var.cluster_version
  vpc_id                                                = module.vpc.vpc_id
  aws_region                                            = var.aws_region
  subnet_ids                                            = module.vpc.private_subnet_ids
  cluster_endpoint_public_access                        = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs                  = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access                       = var.cluster_endpoint_private_access
  primary_node_group_instance_types                     = var.primary_node_group_instance_types
  primary_node_group_min_size                           = var.primary_node_group_min_size
  primary_node_group_desired_size                       = var.primary_node_group_desired_size
  primary_node_group_max_size                           = var.primary_node_group_max_size
  ml_node_group_instance_types                          = var.ml_node_group_instance_types
  ml_node_group_min_size                                = var.ml_node_group_min_size
  ml_node_group_desired_size                            = var.ml_node_group_desired_size
  ml_node_group_max_size                                = var.ml_node_group_max_size
  ml_node_group_ami_type                                = var.ml_node_group_ami_type
  karpenter_namespace                                   = var.karpenter_namespace
  karpenter_service_account_name                        = var.karpenter_service_account_name
  karpenter_interruption_queue_retention                = var.karpenter_interruption_queue_retention
  enable_bastion_bootstrap                              = local.enable_bastion_bootstrap
  enable_bastion_karpenter_bootstrap                    = var.enable_bastion_karpenter_bootstrap
  karpenter_chart_version                               = var.karpenter_chart_version
  enable_default_karpenter_nodepools                    = var.enable_default_karpenter_nodepools
  enable_bastion_aws_load_balancer_controller_bootstrap = var.enable_bastion_aws_load_balancer_controller_bootstrap
  aws_load_balancer_controller_namespace                = var.aws_load_balancer_controller_namespace
  aws_load_balancer_controller_chart_version            = var.aws_load_balancer_controller_chart_version
  aws_load_balancer_controller_service_account_name     = var.aws_load_balancer_controller_service_account_name
  enable_bastion_argocd_bootstrap                       = var.enable_bastion_argocd_bootstrap
  argocd_namespace                                      = var.argocd_namespace
  argocd_chart_version                                  = var.argocd_chart_version
  argocd_server_service_type                            = var.argocd_server_service_type
  argocd_repo_secret_id                                 = local.argocd_repo_secret_id
  argocd_repo_url                                       = var.argocd_repo_url
  argocd_repo_url_key                                   = var.argocd_repo_url_key
  argocd_repo_username_key                              = var.argocd_repo_username_key
  argocd_repo_password_key                              = var.argocd_repo_password_key
  argocd_root_app_name                                  = var.argocd_root_app_name
  argocd_root_app_path                                  = var.argocd_root_app_path
  argocd_root_app_manifest_path                         = var.argocd_root_app_manifest_path
  argocd_root_app_target_revision                       = var.argocd_root_app_target_revision
  argocd_root_app_destination_namespace                 = var.argocd_root_app_destination_namespace
}

module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/bastion"

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
  source = "./modules/eks_components/argocd"

  namespace           = var.argocd_namespace
  chart_version       = var.argocd_chart_version
  server_service_type = var.argocd_server_service_type
  values              = var.argocd_values

  depends_on = [module.eks]
}

data "aws_secretsmanager_secret" "argocd_repo" {
  count = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? 1 : 0

  name = local.argocd_repo_secret_id
}

resource "aws_eks_access_entry" "bastion_admin" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion_admin]
}

resource "aws_security_group_rule" "bastion_to_eks_api" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.bastion[0].security_group_id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Allow private bastion kubectl access to the EKS API"
}

resource "aws_ssm_association" "argocd_bootstrap" {
  count = local.enable_bastion_bootstrap ? 1 : 0

  name = module.eks.bootstrap_document_name

  parameters = {
    bootstrapRevision = var.argocd_bootstrap_revision
  }

  targets {
    key    = "InstanceIds"
    values = [module.bastion[0].instance_id]
  }

  wait_for_success_timeout_seconds = 1200

  depends_on = [
    aws_eks_access_policy_association.bastion_admin,
    aws_security_group_rule.bastion_to_eks_api,
    module.eks,
  ]
}

resource "terraform_data" "cluster_destroy_cleanup" {
  count = local.enable_bastion_bootstrap ? 1 : 0

  input = {
    aws_region     = var.aws_region
    aws_profile    = var.aws_profile
    cluster_name   = module.eks.cluster_name
    cleanup_script = "${path.module}/modules/eks_components/scripts/cluster-destroy-cleanup.sh"
    vpc_id         = module.vpc.vpc_id
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      AWS_REGION='${self.input.aws_region}' AWS_PROFILE='${self.input.aws_profile}' VPC_ID='${self.input.vpc_id}' /bin/bash '${self.input.cleanup_script}'
    EOT
  }

  depends_on = [
    aws_ssm_association.argocd_bootstrap,
    module.bastion,
    module.eks,
    module.vpc,
  ]
}

resource "terraform_data" "vpc_final_destroy_cleanup" {
  count = local.enable_bastion_bootstrap ? 1 : 0

  input = {
    aws_region     = var.aws_region
    aws_profile    = var.aws_profile
    cleanup_script = "${path.module}/modules/eks_components/scripts/delete-k8s-security-groups.sh"
    vpc_id         = module.vpc.vpc_id
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      AWS_REGION='${self.input.aws_region}' AWS_PROFILE='${self.input.aws_profile}' VPC_ID='${self.input.vpc_id}' /bin/bash '${self.input.cleanup_script}'
    EOT
  }

  depends_on = [
    module.eks,
    module.vpc,
  ]
}
