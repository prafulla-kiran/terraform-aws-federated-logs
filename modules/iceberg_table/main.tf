resource "aws_glue_catalog_table" "this" {
  name          = "${var.naming_prefix}-${var.table_name}"
  database_name = var.glue_db_name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    "format"                                     = "parquet"
    "write.target-file-size-bytes"               = "26214400" # 25 MB
    "write.metadata.delete-after-commit.enabled" = "true"
    "write.metadata.previous-versions-max"       = "10"
  }
  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
    }
  }

  storage_descriptor {
    location      = "s3://${var.bucket_name}/${var.glue_db_name}/${var.naming_prefix}-${var.table_name}"
    columns {
      name = "logtype"
      type = "string"
      parameters = {
        "iceberg.field.current"  = "true"
        "iceberg.field.id"       = "1"
        "iceberg.field.optional" = "true"
      }
    }
    columns {
      name = "message"
      type = "string"
      parameters = {
        "iceberg.field.current"  = "true"
        "iceberg.field.id"       = "2"
        "iceberg.field.optional" = "true"
      }
    }
    columns {
      name = "timestamp"
      type = "timestamp"
      parameters = {
        "iceberg.field.current"  = "true"
        "iceberg.field.id"       = "3"
        "iceberg.field.optional" = "false"
      }
    }
    columns {
      name = "guid"
      type = "string"
      parameters = {
        "iceberg.field.current"  = "true"
        "iceberg.field.id"       = "4"
        "iceberg.field.optional" = "true"
      }
    }
  }
}

resource "aws_glue_catalog_table_optimizer" "compaction" {
  catalog_id    = var.aws_account_id
  database_name = var.glue_db_name
  table_name    = aws_glue_catalog_table.this.name
  type          = "compaction"
  configuration {
    role_arn = var.glue_service_role_arn
    enabled  = true
  }
}

resource "aws_glue_catalog_table_optimizer" "iceberg_retention" {
  catalog_id    = var.aws_account_id
  database_name = var.glue_db_name
  table_name    = aws_glue_catalog_table.this.name
  type          = "retention"
  configuration {
    role_arn = var.glue_service_role_arn
    enabled  = true
    retention_configuration {
      iceberg_configuration {
        snapshot_retention_period_in_days = var.retention_days
        number_of_snapshots_to_retain     = 1
        clean_expired_files               = true
      }
    }
  }
}
