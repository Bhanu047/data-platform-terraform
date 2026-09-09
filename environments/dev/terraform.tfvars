environment = "dev"
region      = "us-east-1"

# Dev is disposable, so tearing it down should not require emptying buckets
# by hand. The guard in main.tf makes this a no-op if it is ever copied into
# a prod tfvars by accident.
force_destroy_buckets = true

extra_tags = {
  CostCentre = "data-engineering"
  Retention  = "short"
}
