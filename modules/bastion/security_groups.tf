resource "aws_security_group" "this" {
  name        = "${var.name}-bastion"
  description = "Private SSM bastion/admin host"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-bastion"
  }
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.this.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
