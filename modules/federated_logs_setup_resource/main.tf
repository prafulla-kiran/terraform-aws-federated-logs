resource "aws_s3_bucket" "this" {
  bucket = local.setup_naming_prefix
  region = var.aws_region
}

resource "aws_glue_catalog_database" "this" {
  name        = lower(replace(local.setup_naming_prefix, "-", "_"))
  region      = var.aws_region
  description = "Glue database containing NR resources for federated logs"
}