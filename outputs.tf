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

output "pipeline_readable_bucket_arns" {
  description = "Buckets the pipeline role may read. Exposed so the boundary is assertable."
  value       = local.pipeline_readable_arns
}

output "pipeline_writable_bucket_arns" {
  description = "Buckets the pipeline role may write. Raw is deliberately absent."
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
