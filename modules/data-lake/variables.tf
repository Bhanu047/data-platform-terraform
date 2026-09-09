variable "name_prefix" {
  description = "Prefix for every resource. Usually \"<org>-<env>\"."
  type        = string

  validation {
    # S3 bucket names are globally unique, DNS-cased and awkward. Catching a
    # bad prefix here beats an apply that fails halfway through creating a
    # dozen resources.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be lowercase alphanumeric with hyphens, 3-32 chars."
  }
}

variable "layers" {
  description = <<-EOT
    The lake's layers, each becoming its own bucket.

    Separate buckets rather than prefixes in one bucket: bucket policies and
    lifecycle rules apply per bucket, so a shared bucket forces every access
    rule to be expressed as a prefix condition. Those are easy to write
    slightly wrong and hard to audit.
  EOT
  type = map(object({
    # Days before an object moves to infrequent access. null disables it.
    transition_ia_days = optional(number)
    # Days before it moves to Glacier. null disables it.
    transition_glacier_days = optional(number)
    # Days before non-current versions are purged.
    noncurrent_expiry_days = optional(number, 90)
  }))

  default = {
    raw = {
      # Raw data is read constantly for the first month, then rarely.
      transition_ia_days      = 30
      transition_glacier_days = 180
      noncurrent_expiry_days  = 365
    }
    staging = {
      # Regenerated from raw, so old versions are worth little.
      transition_ia_days     = 30
      noncurrent_expiry_days = 30
    }
    curated = {
      # Queried continuously; moving it to IA would cost more in retrieval
      # than it saves in storage.
      noncurrent_expiry_days = 180
    }
  }
}

variable "kms_key_arn" {
  description = <<-EOT
    Customer-managed KMS key for at-rest encryption. When null, falls back to
    SSE-S3 (AES256).

    SSE-S3 is encrypted but the key is AWS-managed, so access cannot be
    revoked independently of the bucket policy. A customer-managed key is
    what auditors ask for; it is optional here so the module works before
    the key exists.
  EOT
  type        = string
  default     = null
}

variable "force_destroy" {
  description = <<-EOT
    Allow `terraform destroy` to delete non-empty buckets.

    Defaults to false. A true default would mean a destroy in the wrong
    workspace silently deletes the data lake, and there is no undo.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
