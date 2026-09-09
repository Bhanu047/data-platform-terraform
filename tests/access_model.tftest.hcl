# The access boundary: who can touch what.
#
# Asserted on layers rather than on ARNs, and at plan time rather than
# through a mocked apply. Both choices are for the same reason: an ARN is
# computed by AWS, so it is unknown during a plan and synthetic during a
# mocked apply. Asserting on either means asserting on something the test
# harness invented.
#
# The layer lists are real configuration. They are also the form a reviewer
# reasons in -- "the pipeline cannot write to raw" is the claim worth
# testing, and it survives any change to how ARNs are built.
#
# The rendered IAM policy is deliberately not asserted on either: a mocked
# provider returns a placeholder for aws_iam_policy_document.json, so a test
# against it would be a test against the mock.

mock_provider "aws" {}

# `mock_provider` synthesises a placeholder string for every computed
# attribute, including `aws_iam_policy_document.json`. The AWS provider then
# rejects it, because `assume_role_policy` is validated as JSON while the
# plan is being built.
#
# These hand those two data sources a syntactically valid document so the
# resources can be planned. Nothing below asserts on them -- an assertion
# against an override is an assertion against the fixture. The access model
# is checked through the layer outputs, which are real configuration.
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
  command = plan

  assert {
    condition     = !contains(output.pipeline_writable_layers, "raw")
    error_message = "The pipeline must not be able to write to the raw layer."
  }
}

run "pipeline_can_read_what_it_needs" {
  command = plan

  assert {
    condition     = contains(output.pipeline_readable_layers, "raw")
    error_message = "The pipeline needs read access to raw."
  }

  assert {
    condition     = contains(output.pipeline_readable_layers, "staging")
    error_message = "The pipeline needs read access to staging."
  }
}

run "pipeline_can_write_where_it_should" {
  command = plan

  assert {
    condition     = contains(output.pipeline_writable_layers, "curated")
    error_message = "The pipeline needs write access to curated."
  }

  assert {
    condition     = contains(output.pipeline_writable_layers, "staging")
    error_message = "The pipeline needs write access to staging."
  }
}

run "every_granted_layer_actually_exists" {
  command = plan

  # A typo in the access model would otherwise grant nothing and fail
  # silently at apply time, which is the worst place to find out.
  assert {
    condition = alltrue([
      for layer in concat(output.pipeline_readable_layers, output.pipeline_writable_layers) :
      contains(keys(output.bucket_names), layer)
    ])
    error_message = "The access model names a layer that the lake does not create."
  }
}
