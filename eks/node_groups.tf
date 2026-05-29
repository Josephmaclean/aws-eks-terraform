resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "primary"
  node_role_arn   = aws_iam_role.managed_nodes.arn
  subnet_ids      = var.subnet_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = var.primary_node_group_instance_types

  labels = {
    workload = "primary"
  }

  scaling_config {
    min_size     = var.primary_node_group_min_size
    desired_size = var.primary_node_group_desired_size
    max_size     = var.primary_node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(local.karpenter_discovery_tags, {
    Name = "${var.cluster_name}-primary"
  })

  depends_on = [
    aws_iam_role_policy_attachment.managed_nodes,
  ]
}

resource "aws_eks_node_group" "ml" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ml"
  node_role_arn   = aws_iam_role.managed_nodes.arn
  subnet_ids      = var.subnet_ids
  ami_type        = var.ml_node_group_ami_type
  capacity_type   = "ON_DEMAND"
  instance_types  = var.ml_node_group_instance_types

  labels = {
    workload = "ml"
    gpu      = "true"
  }

  taint {
    key    = "workload"
    value  = "ml"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    min_size     = var.ml_node_group_min_size
    desired_size = var.ml_node_group_desired_size
    max_size     = var.ml_node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(local.karpenter_discovery_tags, {
    Name = "${var.cluster_name}-ml"
  })

  depends_on = [
    aws_iam_role_policy_attachment.managed_nodes,
  ]
}
