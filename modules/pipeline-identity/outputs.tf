output "role_arn" {
  description = "ARN of the pipeline role."
  value       = aws_iam_role.pipeline.arn
}

output "role_name" {
  value = aws_iam_role.pipeline.name
}

output "policy_json" {
  description = "The rendered policy. Exposed so tests can assert on it."
  value       = data.aws_iam_policy_document.pipeline.json
}
