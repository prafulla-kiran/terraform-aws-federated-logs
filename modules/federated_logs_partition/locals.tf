locals {
  default_partition_name = "default"
  iceberg_table_name_prefix = "nr-fed-logs"

  all_tables = merge(
    { "${local.default_partition_name}" = var.default_table_setting },
    var.non_default_tables
  )
}