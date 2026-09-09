terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  /*
    Remote state, commented out because it cannot be created by the same
    configuration that uses it -- the bucket has to exist first. In a real
    account this is bootstrapped once, by hand or by a separate tiny
    configuration, and then filled in here.

    The two settings that matter:

    `use_lockfile` (or a DynamoDB table on older versions) stops two applies
    running at once. Without locking, two engineers applying simultaneously
    produce a state file describing neither of their intentions, and
    recovering means hand-editing state.

    `encrypt` because state contains every value Terraform touched,
    including anything marked sensitive. A state file is a credentials file.
  */
  # backend "s3" {
  #   bucket       = "acme-terraform-state"
  #   key          = "data-platform/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
