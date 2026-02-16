resource "aws_s3_bucket" "this" {
  bucket = "${var.naming_prefix}-${local.s3_bucket_name}"
  region = var.aws_region
  force_destroy = true
}

resource "aws_glue_catalog_database" "this" {
  name = "${var.naming_prefix}-${local.glue_catalog_db_name}"
  region = var.aws_region
  description = "Glue database containing NR resources for federated logs"
}