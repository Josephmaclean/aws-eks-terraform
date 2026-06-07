locals {
  mlflow_oidc_issuer_hostpath = replace(module.eks.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "mlflow_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.mlflow_oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.mlflow_oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.mlflow_namespace}:${var.mlflow_service_account_name}"]
    }
  }
}

data "aws_iam_policy_document" "mlflow_artifacts_access" {
  statement {
    sid = "AllowBucketListing"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      aws_s3_bucket.mlflow_artifacts.arn,
    ]
  }

  statement {
    sid = "AllowObjectAccess"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.mlflow_artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_role" "mlflow" {
  name               = "${var.name}-mlflow-role"
  assume_role_policy = data.aws_iam_policy_document.mlflow_assume_role.json
}

resource "aws_iam_policy" "mlflow_artifacts_access" {
  name   = "${var.name}-mlflow-artifacts-access"
  policy = data.aws_iam_policy_document.mlflow_artifacts_access.json
}

resource "aws_iam_role_policy_attachment" "mlflow_artifacts_access" {
  role       = aws_iam_role.mlflow.name
  policy_arn = aws_iam_policy.mlflow_artifacts_access.arn
}
