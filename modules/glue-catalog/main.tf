/*
  Glue databases, declared rather than created by a crawler.

  Crawlers are convenient and they infer schemas, which is the same problem
  as inferSchema in a Spark job: the shape of your table depends on which
  files happened to be there when it last ran. Declaring the database here
  and letting the pipeline register tables explicitly keeps the catalog a
  product of code rather than of whatever landed last night.
*/

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_glue_catalog_database" "this" {
  for_each = var.databases

  name         = "${replace(var.name_prefix, "-", "_")}_${each.key}"
  description  = each.value.description
  location_uri = each.value.location_uri
}

locals {
  # ARNs the IAM module needs. Built here because this module knows the
  # naming rule and nothing else should have to reproduce it.
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  database_arns = flatten([
    for key, db in aws_glue_catalog_database.this : [
      "arn:aws:glue:${local.region}:${local.account_id}:catalog",
      "arn:aws:glue:${local.region}:${local.account_id}:database/${db.name}",
      "arn:aws:glue:${local.region}:${local.account_id}:table/${db.name}/*",
    ]
  ])
}
