# The access boundary: who can touch what.
#
# Asserted on the root outputs rather than on the rendered IAM policy,
# because a mocked provider returns a synthetic value for
# aws_iam_policy_document.json -- asserting on that would be asserting on
# the mock. The bucket lists are real configuration and are the decision
# that actually matters.

mock_provider "aws" {}

variables {
  environment = "dev"
  org         = "acme"
}

run "pipeline_cannot_write_to_raw" {
  command = plan

  assert {
    condition = !contains(
      output.pipeline_writable_bucket_arns,
      output.bucket_arns["raw"]
    )
    error_message = "The pipeline must not be able to write to the raw layer."
  }
}

run "pipeline_can_read_what_it_needs" {
  command = plan

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
  command = plan

  assert {
    condition     = contains(output.pipeline_writable_bucket_arns, output.bucket_arns["curated"])
    error_message = "The pipeline needs write access to curated."
  }

  assert {
    condition     = contains(output.pipeline_writable_bucket_arns, output.bucket_arns["staging"])
    error_message = "The pipeline needs write access to staging."
  }
}
