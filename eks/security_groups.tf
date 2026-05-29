resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "Security group selected by EKS and Karpenter nodes"
  vpc_id      = var.vpc_id

  tags = merge(local.karpenter_discovery_tags, {
    Name = "${var.cluster_name}-nodes"
  })
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type                     = "ingress"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}
