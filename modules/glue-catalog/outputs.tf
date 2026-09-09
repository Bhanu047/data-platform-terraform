output "database_names" {
  value = { for key, db in aws_glue_catalog_database.this : key => db.name }
}

output "database_arns" {
  description = "Catalog, database and table ARNs, for the pipeline policy."
  value       = local.database_arns
}
