/*
  The pipeline's identity, scoped to exactly what it needs.

  No wildcards on resources. `s3:*` on `*` is the policy everyone writes on
  the first day and nobody revisits, and it means a compromised job can read
  every bucket in the account, including the one holding whatever the
  security team is storing.

  Read and write are separate statements against separate bucket lists,
  because "can read raw" and "can write curated" are genuinely different
  permissions and collapsing them removes the ability to say so.
*/

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.trusted_service]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name               = "${var.name_prefix}-pipeline"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  # A permissions boundary would go here in a real account. It caps what the
  # role can ever be granted, even by someone with permission to edit the
  # policy below -- which is the control that survives a mistake.

  tags = var.tags
}

data "aws_iam_policy_document" "pipeline" {
  # Listing is a bucket-level action; without it a read of an unknown key
  # returns AccessDenied instead of NoSuchKey, and every debugging session
  # starts by chasing the wrong error.
  dynamic "statement" {
    for_each = length(var.readable_bucket_arns) > 0 ? [1] : []

    content {
      sid       = "ListReadableBuckets"
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = var.readable_bucket_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.readable_bucket_arns) > 0 ? [1] : []

    content {
      sid       = "ReadObjects"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:GetObjectVersion"]
      resources = [for arn in var.readable_bucket_arns : "${arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.writable_bucket_arns) > 0 ? [1] : []

    content {
      sid       = "ListWritableBuckets"
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = var.writable_bucket_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.writable_bucket_arns) > 0 ? [1] : []

    content {
      sid    = "WriteObjects"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:DeleteObject",
        # Multipart uploads fail without these, and the error names neither.
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
      ]
      resources = [for arn in var.writable_bucket_arns : "${arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.glue_database_arns) > 0 ? [1] : []

    content {
      sid    = "CatalogAccess"
      effect = "Allow"
      actions = [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:BatchCreatePartition",
        "glue:BatchUpdatePartition",
      ]
      resources = var.glue_database_arns
    }
  }

  # Deliberately absent: glue:DeleteDatabase and glue:DeleteTable. A pipeline
  # that can drop a table will eventually drop a table.
}

resource "aws_iam_policy" "pipeline" {
  name        = "${var.name_prefix}-pipeline"
  description = "Least-privilege access for the ${var.name_prefix} data pipeline."
  policy      = data.aws_iam_policy_document.pipeline.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "pipeline" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.pipeline.arn
}
