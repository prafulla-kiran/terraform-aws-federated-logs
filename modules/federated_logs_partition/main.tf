resource "aws_s3_object" "folder" {
  for_each = local.all_tables
  bucket   = var.s3_bucket_name
  key      = "${var.glue_catalog_db_name}/${each.key}/"
}

resource "aws_glue_catalog_table" "iceberg_table" {
  for_each = local.all_tables

  name          = each.key
  database_name = var.glue_catalog_db_name

  lifecycle {
    precondition {
      condition     = !local.has_duplicates
      error_message = <<-EOT
        Duplicate partition names detected after sanitization!
        The following sanitized table names appear multiple times: ${join(", ", distinct(local.duplicate_names))}

        This happens when different partition_tables keys result in the same final name after:
        - Adding prefix: newrelic_fed_logs_${var.setup_name}_
        - Lowercasing and replacing special characters with underscores
        - Truncating to 255 characters

        Please use more distinct partition names in your partition_tables variable.
      EOT
    }

    ignore_changes = [
      # Prevent TF from fighting with Athena/Iceberg over these dynamic keys
      parameters["previous_metadata_location"],
      parameters["metadata_location"],
      parameters["current-snapshot-id"],
      parameters["current-snapshot-timestamp-ms"],
      parameters["current-snapshot-summary"],
      parameters["snapshot-count"]
    ]
  }

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = 2

      iceberg_table_input {
        location = "s3://${var.s3_bucket_name}/${var.glue_catalog_db_name}/${each.key}/"

        properties = local.resolved_table_params[each.key]

        schema {
          schema_id = 0
          type      = "struct"

          fields {
            id       = 1
            name     = "logtype"
            required = false
            type     = <<EOF
"string"
EOF
          }
          fields {
            id       = 2
            name     = "message"
            required = false
            type     = <<EOF
"string"
EOF
          }
          fields {
            id       = 3
            name     = "timestamp"
            required = true
            type     = <<EOF
"timestamp"
EOF
          }
          fields {
            id       = 4
            name     = "guid"
            required = false
            type     = <<EOF
"string"
EOF
          }
          fields {
            id       = 5
            name     = "messageId"
            required = true
            type     = <<EOF
"string"
EOF
          }
        }

        partition_spec {
          fields {
            name      = "timestamp_hour"
            source_id = 3
            transform = "hour"
          }
          spec_id = 0
        }
      }
    }
  }
}
