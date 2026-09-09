environment = "prod"
region      = "us-east-1"

# Set once the KMS key exists. Until then the buckets use SSE-S3, which is
# encrypted but with an AWS-managed key.
# kms_key_arn = "arn:aws:kms:us-east-1:111122223333:key/..."

force_destroy_buckets = false

extra_tags = {
  CostCentre = "data-engineering"
  Retention  = "long"
  DataClass  = "confidential"
}
