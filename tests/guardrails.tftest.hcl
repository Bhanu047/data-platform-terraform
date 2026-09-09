# Guards that exist to stop a mistake, tested at the root where they live.

mock_provider "aws" {}

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
