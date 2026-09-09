# Guards that exist to stop a mistake, tested at the root where they live.

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
  org = "acme"
}

run "prod_refuses_force_destroy_even_when_asked" {
  command = plan

  variables {
    environment           = "prod"
    force_destroy_buckets = true
  }

  # Asking must not be the same as receiving. A destroy in the wrong
  # workspace should fail on a non-empty bucket rather than succeed quietly.
  assert {
    condition     = output.force_destroy_effective == false
    error_message = "force_destroy must be refused in prod even when requested."
  }
}

run "dev_honours_force_destroy" {
  command = plan

  variables {
    environment           = "dev"
    force_destroy_buckets = true
  }

  assert {
    condition     = output.force_destroy_effective == true
    error_message = "Dev should honour force_destroy so a sandbox can be torn down."
  }
}

run "rejects_an_unknown_environment" {
  command = plan

  variables {
    environment = "producton"
  }

  expect_failures = [var.environment]
}
