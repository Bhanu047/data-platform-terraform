# The access boundary: who can touch what.
#
# Asserted on the root outputs rather than on the rendered IAM policy,
# because a mocked provider returns a synthetic value for
# aws_iam_policy_document.json -- asserting on that would be asserting on
# the mock. The bucket lists are real configuration and are the decision
# that actually matters.
#
# These use `command = apply` where the others use `plan`, and the reason is
# specific: a bucket ARN is computed by AWS, so during a plan it is unknown
# and reads as null, which makes `contains()` fail on a null argument rather
# than answer the question. Under a mocked provider an apply calls nothing
# real -- it just resolves the computed attributes to synthetic values, and
# both sides of each comparison resolve to the same one, so the assertion
# means what it says.

mock_provider "aws" {}

# `mock_provider` synthesises a placeholder string for every computed
# attribute, including `aws_iam_policy_document.json`. The AWS provider then
# rejects it, because `assume_role_policy` is validated as JSON while the
# plan is being built.
#
# These overrides hand those two data sources a syntactically valid document
# so the resources can be planned. Nothing below asserts on them: an
# assertion against an override is an assertion against the fixture, which
# proves nothing. The access model is asserted through the root outputs
# instead, where the values are real configuration.
override_data {
  target = module.pipeline_identity.data.aws_iam_policy_document.assume_role
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = module.pipeline_identity.data.aws_iam_policy_document.pipeline
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  environment = "dev"
  org         = "acme"
}

run "pipeline_cannot_write_to_raw" {
  command = apply

  assert {
    condition = !contains(
      output.pipeline_writable_bucket_arns,
      output.bucket_arns["raw"]
    )
    error_message = "The pipeline must not be able to write to the raw layer."
  }
}

run "pipeline_can_read_what_it_needs" {
  command = apply

  assert {
    condition     = contains(output.pipeline_readable_bucket_arns, output.bucket_arns["raw"])
    error_message = "The pipeline needs read access to raw."
  }

  assert {
    condition     = contains(output.pipeline_readable_bucket_arns, output.bucket_arns["staging"])
    error_message = "The pipeline needs read access to staging."
  }
}

run "pipeline_can_write_where_it_should" {
  command = apply

  assert {
    condition     = contains(output.pipeline_writable_bucket_arns, output.bucket_arns["curated"])
    error_message = "The pipeline needs write access to curated."
  }

  assert {
    condition     = contains(output.pipeline_writable_bucket_arns, output.bucket_arns["staging"])
    error_message = "The pipeline needs write access to staging."
  }
}
