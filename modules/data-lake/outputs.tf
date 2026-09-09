output "bucket_names" {
  description = "Layer name to bucket name."
  value       = { for layer, bucket in aws_s3_bucket.this : layer => bucket.id }
}

output "bucket_arns" {
  description = "Layer name to bucket ARN. Consumed by the IAM module."
  value       = { for layer, bucket in aws_s3_bucket.this : layer => bucket.arn }
}
