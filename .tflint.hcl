# tflint catches what `terraform validate` does not: deprecated syntax,
# unused declarations, and provider-specific mistakes such as an instance
# type that does not exist. Validate only checks that the configuration
# parses and type-checks.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
