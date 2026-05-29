module "vpc" {
  source = "./modules/vpc"

  name                  = var.name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  karpenter_discovery   = var.cluster_name
  public_subnet_cidrs   = var.public_subnet_cidrs
  firewall_subnet_cidrs = var.firewall_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

module "eks" {
  source = "./eks"

  cluster_name                           = var.cluster_name
  cluster_version                        = var.cluster_version
  vpc_id                                 = module.vpc.vpc_id
  subnet_ids                             = module.vpc.private_subnet_ids
  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs   = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access        = var.cluster_endpoint_private_access
  primary_node_group_instance_types      = var.primary_node_group_instance_types
  primary_node_group_min_size            = var.primary_node_group_min_size
  primary_node_group_desired_size        = var.primary_node_group_desired_size
  primary_node_group_max_size            = var.primary_node_group_max_size
  ml_node_group_instance_types           = var.ml_node_group_instance_types
  ml_node_group_min_size                 = var.ml_node_group_min_size
  ml_node_group_desired_size             = var.ml_node_group_desired_size
  ml_node_group_max_size                 = var.ml_node_group_max_size
  ml_node_group_ami_type                 = var.ml_node_group_ami_type
  karpenter_namespace                    = var.karpenter_namespace
  karpenter_service_account_name         = var.karpenter_service_account_name
  karpenter_interruption_queue_retention = var.karpenter_interruption_queue_retention
}
