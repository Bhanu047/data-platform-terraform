/*
  The lake itself: one bucket per layer, with encryption, versioning,
  lifecycle and public access all set explicitly.

  Explicitly is the point. Most of these have permissive or absent defaults
  in the AWS API, and "we thought it inherited that" is how buckets end up
  public. Every control is stated even where the default happens to be
  correct today, because defaults change and a stated value shows intent.
*/

locals {
  buckets = {
    for layer, config in var.layers :
    layer => merge(config, { name = "${var.name_prefix}-${layer}" })
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value.name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name  = each.value.name
    Layer = each.key
  })
}

# Public access is blocked at the bucket level as well as the account level.
# Belt and braces on purpose: account-level settings are one console click
# from being changed by someone who does not know what depends on them.
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    # Without this, every object read makes its own KMS call. On a Spark job
    # reading tens of thousands of files that is both slow and expensive;
    # bucket keys cut the KMS request count by orders of magnitude.
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# Versioning is what turns "someone overwrote the partition" from an
# incident into an inconvenience. The storage cost is bounded by the
# lifecycle rules below.
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  # Lifecycle rules on a versioned bucket must clean up non-current versions
  # or storage grows without limit -- every overwrite leaves the old object
  # behind, invisible in the console but fully billed.
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = each.value.noncurrent_expiry_days
    }
  }

  dynamic "rule" {
    for_each = each.value.transition_ia_days == null ? [] : [1]

    content {
      id     = "transition-to-ia"
      status = "Enabled"

      filter {}

      transition {
        days          = each.value.transition_ia_days
        storage_class = "STANDARD_IA"
      }
    }
  }

  dynamic "rule" {
    for_each = each.value.transition_glacier_days == null ? [] : [1]

    content {
      id     = "transition-to-glacier"
      status = "Enabled"

      filter {}

      transition {
        days          = each.value.transition_glacier_days
        storage_class = "GLACIER_IR"
      }
    }
  }

  # Incomplete uploads are invisible in the console and billed indefinitely.
  # A failed Spark write can leave thousands behind.
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# Refuse any request that is not TLS. S3 accepts plain HTTP by default, and
# a policy is the only way to turn that off.
resource "aws_s3_bucket_policy" "tls_only" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id
  policy = data.aws_iam_policy_document.tls_only[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

data "aws_iam_policy_document" "tls_only" {
  for_each = aws_s3_bucket.this

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [each.value.arn, "${each.value.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
