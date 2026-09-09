# Tests for the lake module, run against the module directly.
#
# `mock_provider` means these need no AWS account and no credentials --
# Terraform synthesises provider responses instead of calling the API, so
# the loop is seconds and CI runs on a fork.
#
# Worth stating the limit: this tests the plan, not the cloud. It catches a
# bucket created without a public access block. It cannot catch a bucket
# policy that AWS itself would reject. That needs an apply in a sandbox
# account, which is a different and slower kind of test.

mock_provider "aws" {}

run "creates_one_bucket_per_layer" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    name_prefix = "acme-dev"
  }

  assert {
    condition     = length(aws_s3_bucket.this) == 3
    error_message = "Expected three lake layers: raw, staging, curated."
  }

  assert {
    condition     = aws_s3_bucket.this["raw"].bucket == "acme-dev-raw"
    error_message = "Bucket name should be <prefix>-<layer>."
  }
}

run "public_access_is_blocked_on_every_bucket" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    name_prefix = "acme-dev"
  }

  assert {
    condition = alltrue([
      for b in values(aws_s3_bucket_public_access_block.this) :
      b.block_public_acls && b.block_public_policy &&
      b.ignore_public_acls && b.restrict_public_buckets
    ])
    error_message = "Every bucket must block public access on all four settings."
  }
}

run "versioning_is_enabled_everywhere" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    name_prefix = "acme-dev"
  }

  assert {
    condition = alltrue([
      for v in values(aws_s3_bucket_versioning.this) :
      one(v.versioning_configuration).status == "Enabled"
    ])
    error_message = "Versioning must be on; it is what makes an overwrite recoverable."
  }
}

run "encryption_defaults_to_sse_s3" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    name_prefix = "acme-dev"
    kms_key_arn = null
  }

  assert {
    condition = alltrue([
      for e in values(aws_s3_bucket_server_side_encryption_configuration.this) :
      one(one(e.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    ])
    error_message = "With no KMS key the buckets must still be encrypted, via SSE-S3."
  }
}

run "encryption_uses_kms_when_a_key_is_supplied" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    name_prefix = "acme-dev"
    kms_key_arn = "arn:aws:kms:us-east-1:111122223333:key/abcd1234-0000-0000-0000-abcdefabcdef"
  }

  assert {
    condition = alltrue([
      for e in values(aws_s3_bucket_server_side_encryption_configuration.this) :
      one(one(e.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    ])
    error_message = "A supplied KMS key should switch encryption to aws:kms."
  }

  assert {
    condition = alltrue([
      for e in values(aws_s3_bucket_server_side_encryption_configuration.this) :
      one(e.rule).bucket_key_enabled == true
    ])
    error_message = "Bucket keys must be on with KMS, or every object read costs a KMS call."
  }
}

run "rejects_an_invalid_name_prefix" {
  command = plan

  module {
    source = "./modules/data-lake"
  }

  variables {
    # Uppercase and underscores are both illegal in a bucket name.
    name_prefix = "Acme_Dev"
  }

  expect_failures = [var.name_prefix]
}
