terraform {
  # 1.7 for `terraform test` with mocked providers, which is what lets this
  # module be tested without an AWS account.
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Pessimistic on the minor, not pinned to a patch: security fixes land
      # in patches and should not need a code change to pick up, while a
      # minor bump can rename attributes and deserves a deliberate upgrade.
      version = "~> 5.60"
    }
  }
}
