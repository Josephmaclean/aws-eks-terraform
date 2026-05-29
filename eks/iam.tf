data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "managed_nodes" {
  name               = "${var.cluster_name}-managed-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "managed_nodes" {
  for_each = toset(local.node_role_policy_arns)

  role       = aws_iam_role.managed_nodes.name
  policy_arn = each.value
}

resource "aws_iam_role" "karpenter_nodes" {
  name               = "${var.cluster_name}-karpenter-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "karpenter_nodes" {
  for_each = toset(local.node_role_policy_arns)

  role       = aws_iam_role.karpenter_nodes.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "karpenter_controller_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_name}-karpenter-controller-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role.json
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid = "AllowScopedEC2InstanceActions"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:TerminateInstances",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowEC2ReadActions"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowPricingReadActions"

    actions = ["pricing:GetProducts"]

    resources = ["*"]
  }

  statement {
    sid = "AllowPassingKarpenterNodeRole"

    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_nodes.arn]
  }

  statement {
    sid = "AllowInstanceProfileManagement"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowEksDescribeCluster"

    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.this.arn]
  }

  statement {
    sid = "AllowInterruptionQueueAccess"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]

    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name   = "${var.cluster_name}-karpenter-controller"
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}
