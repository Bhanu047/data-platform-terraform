variable "environment" {
  description = "Environment name. Becomes part of every resource name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "org" {
  description = "Short organisation slug, used as the name prefix."
  type        = string
  default     = "acme"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "kms_key_arn" {
  description = "Customer-managed key for bucket encryption. Null falls back to SSE-S3."
  type        = string
  default     = null
}

variable "force_destroy_buckets" {
  description = <<-EOT
    Whether `terraform destroy` may delete non-empty buckets.

    False everywhere except a throwaway sandbox. See the guard in main.tf --
    setting this in prod is refused rather than trusted.
  EOT
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional tags merged over the defaults."
  type        = map(string)
  default     = {}
}
