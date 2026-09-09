variable "name_prefix" {
  description = "Prefix for role and policy names."
  type        = string
}

variable "readable_bucket_arns" {
  description = "Buckets the pipeline may read. Usually raw and staging."
  type        = list(string)
}

variable "writable_bucket_arns" {
  description = "Buckets the pipeline may write. Usually staging and curated."
  type        = list(string)
}

variable "trusted_service" {
  description = <<-EOT
    The AWS service allowed to assume this role.

    A service principal rather than a user or an access key: keys leak, get
    committed, and outlive the person who made them. A role assumed by the
    compute that needs it has no long-lived credential to lose.
  EOT
  type        = string
  default     = "glue.amazonaws.com"

  validation {
    condition     = endswith(var.trusted_service, ".amazonaws.com")
    error_message = "trusted_service must be an AWS service principal, e.g. glue.amazonaws.com."
  }
}

variable "glue_database_arns" {
  description = "Catalog resources the pipeline may read and update."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
