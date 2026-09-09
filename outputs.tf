output "bucket_names" {
  description = "Lake buckets by layer."
  value       = module.data_lake.bucket_names
}

output "pipeline_role_arn" {
  description = "Role the Glue/EMR job assumes."
  value       = module.pipeline_identity.role_arn
}

output "glue_databases" {
  value = module.catalog.database_names
}

output "pipeline_readable_layers" {
  description = "Lake layers the pipeline role may read."
  value       = local.pipeline_readable_layers
}

output "pipeline_writable_layers" {
  description = <<-EOT
    Lake layers the pipeline role may write. Raw is deliberately absent: it
    holds the only copy of what the source sent, and a transform job that
    can rewrite its own input can destroy it.
  EOT
  value       = local.pipeline_writable_layers
}

output "pipeline_readable_bucket_arns" {
  description = "The same grant as ARNs, derived from the layer list."
  value       = local.pipeline_readable_arns
}

output "pipeline_writable_bucket_arns" {
  description = "The same grant as ARNs, derived from the layer list."
  value       = local.pipeline_writable_arns
}

output "force_destroy_effective" {
  description = <<-EOT
    Whether buckets can actually be force-destroyed after the prod guard is
    applied. Exposed because "we set the variable" and "the guard let it
    through" are different facts, and only the second one matters.
  EOT
  value       = local.force_destroy
}

output "bucket_arns" {
  description = "Lake bucket ARNs by layer."
  value       = module.data_lake.bucket_arns
}
