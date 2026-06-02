resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = var.karpenter_interruption_queue_retention
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  name = "${var.cluster_name}-karpenter-interruption"

  event_pattern = jsonencode({
    source = [
      "aws.ec2",
      "aws.health",
    ]
    "detail-type" = [
      "EC2 Spot Instance Interruption Warning",
      "EC2 Instance Rebalance Recommendation",
      "EC2 Instance State-change Notification",
      "AWS Health Event",
    ]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

data "aws_iam_policy_document" "karpenter_interruption_queue" {
  statement {
    sid     = "AllowEventBridgeToSendMessages"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue.json
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.karpenter_namespace
  service_account = var.karpenter_service_account_name
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.karpenter_controller,
  ]
}

resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]
}

resource "aws_eks_access_entry" "karpenter_nodes" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.karpenter_nodes.arn
  type          = "EC2_LINUX"
}
