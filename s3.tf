locals {
  mlflow_artifacts_bucket_name = "${var.name}-mlflow-artifacts"
}

resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = local.mlflow_artifacts_bucket_name

  tags = {
    Name    = local.mlflow_artifacts_bucket_name
    Purpose = "mlflow-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "mlflow_artifacts_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.mlflow_artifacts.arn,
      "${aws_s3_bucket.mlflow_artifacts.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  policy = data.aws_iam_policy_document.mlflow_artifacts_bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.mlflow_artifacts,
    aws_s3_bucket_ownership_controls.mlflow_artifacts,
  ]
}
