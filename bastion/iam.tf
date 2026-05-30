data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "eks_access" {
  statement {
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_access" {
  name   = "${var.name}-bastion-eks-access"
  policy = data.aws_iam_policy_document.eks_access.json
}

resource "aws_iam_role_policy_attachment" "eks_access" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.eks_access.arn
}

data "aws_iam_policy_document" "secrets_access" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = var.secret_arns
  }
}

resource "aws_iam_policy" "secrets_access" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  name   = "${var.name}-bastion-secrets-access"
  policy = data.aws_iam_policy_document.secrets_access[0].json
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.secrets_access[0].arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-bastion"
  role = aws_iam_role.this.name
}
