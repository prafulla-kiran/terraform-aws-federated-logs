data "aws_region" "current" {
  region = var.region
}

locals {
  # Glue table name for the default partition. Mirrors the partition
  # module's internal formula (locals.tf — `setup_naming_prefix` +
  # `default_partition_name`, sanitised lowercase + non-alphanumerics →
  # underscore, truncated to 255 chars) so the table name on
  # newrelic_federated_logs_setup.default_partition.storage.table matches
  # the aws_glue_catalog_table that the partition module actually creates
  # for the default. If the partition module's naming changes, change this
  # in lock-step.
  default_partition_table = substr(replace(lower("newrelic_fed_logs_${var.setup_name}_Log_Federated"), "/[^a-z0-9_]/", "_"), 0, 255)
}

module "setup" {
  source     = "./modules/federated_logs_setup_resource"
  setup_name = var.setup_name
  region     = var.region
}

module "role" {
  source               = "./modules/federated_logs_role"
  setup_name           = var.setup_name
  s3_bucket_name       = module.setup.s3_bucket_name
  glue_catalog_db_name = module.setup.glue_catalog_db_name
  fleet_entity_guid    = var.fleet_entity_guid
  newrelic_region      = var.newrelic_region
  newrelic_org_id      = var.newrelic_org_id
  region               = var.region
}



# ── Federated Logs Setup (NR provider resource) ──────────────────────────────
# Wires the AWS-side resources (S3 bucket, Glue DB) to the NR side. Lives at
# top-level (not inside any module) because it depends on outputs from BOTH
# the setup_resource module AND the role module — putting it inside either
# would create a circular module dependency.
#
# The default_partition block creates the default partition entity in NR
# alongside this setup; its corresponding aws_glue_catalog_table is created
# by the federated_logs_partition module (using the same default_partition_table
# name — kept aligned via the local above).
resource "newrelic_federated_logs_setup" "this" {
  name        = var.setup_name
  description = "Federated logs setup ${var.setup_name}: AWS S3 + Glue catalog as the underlying store, with a default partition created alongside."

  storage {
    data_location_bucket      = module.setup.s3_bucket_name
    database                  = module.setup.glue_catalog_db_name
    data_ingest_connection_id = module.role.fleet_ingest_connection_id
    query_connection_id       = module.role.query_connection_id

    cloud_provider_configuration {
      provider = "AWS"
      region   = data.aws_region.current.id
    }
  }

  default_partition {
    storage {
      table             = local.default_partition_table
      data_location_uri = "s3://${module.setup.s3_bucket_name}/${module.setup.glue_catalog_db_name}/${local.default_partition_table}"
    }

    dynamic "data_retention_policy" {
      for_each = var.default_partition_data_retention_days > 0 ? [1] : []
      content {
        duration = var.default_partition_data_retention_days
        unit     = "DAYS"
      }
    }
  }

  # Forwarder wires the PCG fleet to this setup via pipeline control. fleet_id
  # is the same `var.fleet_entity_guid` we already use elsewhere — the NGEP
  # entity GUID of the fleet that should forward logs into this setup.
  forwarder {
    type = "PIPELINE_CONTROL"
    pipeline_control {
      fleet_id = var.fleet_entity_guid
    }
  }
}

module "partition" {
  source                 = "./modules/federated_logs_partition"
  setup_name             = var.setup_name
  s3_bucket_name         = module.setup.s3_bucket_name
  glue_catalog_db_name   = module.setup.glue_catalog_db_name
  glue_service_role_arn  = module.role.glue_service_role_arn
  default_table_setting  = var.default_table_setting
  partition_tables       = var.partition_tables
  region                 = var.region
  data_retention_enabled = var.data_retention_enabled
}