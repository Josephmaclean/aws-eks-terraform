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
