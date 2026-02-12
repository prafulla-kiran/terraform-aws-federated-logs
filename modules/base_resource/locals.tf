locals {
  permissions_boundary = "arn:aws:iam::${var.aws_account_id}:policy/resource-provisioner-boundary"
  s3_bucket_name     = "nr-fed-logs"
  glue_catalog_db_name = "nr_fed_logs_iceberg_db"
}