# Shared Terraform remote-state S3 bucket for all environments. Versioning +
# SSE + public-access-block + TLS-only bucket policy (Req 2.1, 2.4, 2.5).
# Native S3 locking (use_lockfile) needs only the bucket — no DynamoDB table.

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = { Name = var.state_bucket_name }
}

# Retain every prior version of the state object (Req 2.5).
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for state at rest (Req 2.4).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any non-TLS (HTTP) access to the bucket and its objects.
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json

  # The public access block must settle before attaching a bucket policy.
  depends_on = [aws_s3_bucket_public_access_block.state]
}
