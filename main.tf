/*
  The data platform, composed from three modules.

  One root configuration parameterised by environment, rather than a copied
  directory per environment. Copies drift: someone fixes a lifecycle rule in
  prod, forgets dev, and six months later a bug reproduces in one and not
  the other for reasons nobody can explain. The per-environment tfvars files
  hold the differences and nothing else.
*/

provider "aws" {
  region = var.region

  # Every resource gets these without each module having to remember. A
  # resource with no owner tag is one nobody will admit to when the bill
  # arrives.
  default_tags {
    tags = merge(
      {
        Environment = var.environment
        ManagedBy   = "terraform"
        Project     = "data-platform"
      },
      var.extra_tags,
    )
  }
}

locals {
  name_prefix = "${var.org}-${var.environment}"

  # Guard rather than trust. force_destroy in prod would let a mistyped
  # workspace delete the lake, so it is refused outright instead of being
  # left to review to catch.
  force_destroy = var.environment == "prod" ? false : var.force_destroy_buckets
}

locals {
  /*
    The access model, stated once as data rather than buried in a module
    call. Written this way so it can be asserted on directly in a test and
    read without tracing arguments through a module boundary -- who can
    touch what is the thing a reviewer most needs to check.

    The pipeline reads raw and staging, writes staging and curated. It has
    no write access to raw at all: raw is what the ingestion tier lands, and
    a transform job that can rewrite its own input can destroy the only copy
    of the source data.
  */
  pipeline_readable_arns = [
    module.data_lake.bucket_arns["raw"],
    module.data_lake.bucket_arns["staging"],
  ]

  pipeline_writable_arns = [
    module.data_lake.bucket_arns["staging"],
    module.data_lake.bucket_arns["curated"],
  ]
}

module "data_lake" {
  source = "./modules/data-lake"

  name_prefix   = local.name_prefix
  kms_key_arn   = var.kms_key_arn
  force_destroy = local.force_destroy
}

module "catalog" {
  source = "./modules/glue-catalog"

  name_prefix = local.name_prefix

  databases = {
    raw = {
      description  = "Landed data, as the source sent it."
      location_uri = "s3://${module.data_lake.bucket_names["raw"]}/"
    }
    curated = {
      description  = "Modelled tables, safe for downstream consumers."
      location_uri = "s3://${module.data_lake.bucket_names["curated"]}/"
    }
  }
}

module "pipeline_identity" {
  source = "./modules/pipeline-identity"

  name_prefix = local.name_prefix

  readable_bucket_arns = local.pipeline_readable_arns
  writable_bucket_arns = local.pipeline_writable_arns

  glue_database_arns = module.catalog.database_arns
}
