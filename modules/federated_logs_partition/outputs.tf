output "all_tables" {
  description = "Map of all tables with their names and ARNs"
  value = {
    for k in keys(local.all_tables) : k => {
      name = k
      arn  = "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:table/${var.glue_catalog_db_name}/${k}"
    }
  }
  depends_on = [null_resource.create_iceberg_table]
}
