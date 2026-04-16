# S3 object to store the Glue Spark ETL script
resource "aws_s3_object" "retention_script" {
  count = local.is_retention_enabled ? 1 : 0

  bucket  = var.s3_bucket_name
  key     = "${var.glue_catalog_db_name}/scripts/retention_job.py"
  content = <<-PYTHON
import sys
import json
from datetime import datetime, timedelta, timezone
from pyspark.sql import SparkSession
from awsglue.utils import getResolvedOptions

def main():

    # Parse job parameters
    args = getResolvedOptions(sys.argv, ['DATABASE_NAME', 'TABLE_NAMES'])
    database = args['DATABASE_NAME']
    table_names = args['TABLE_NAMES'].split(',')  # Comma-separated list of tables
    retention_period = "1 DAY"  # Hardcoded for now, will be fetched from NGEP 

    # Parse retention period (format: "7 DAYS" or "1 DAY")
    parts = retention_period.strip().split()
    if len(parts) != 2 or parts[1].upper() not in ['DAY', 'DAYS']:
        raise ValueError(f"Invalid retention format: {retention_period}. Expected '<number> DAYS'")

    days = int(parts[0])
    print(f"Retention period in days: {days} day(s)")

    # Calculate cutoff timestamp aligned to midnight UTC for efficient partition deletion
    # This ensures we delete whole hourly partitions from a fixed 00:00 hours
    now = datetime.now(timezone.utc)
    cutoff = (now - timedelta(days=days)).replace(hour=0, minute=0, second=0, microsecond=0)
    cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')
    print(f"Cutoff timestamp (midnight-aligned): {cutoff_str}")

    # Initialize Spark session with Hive support for Iceberg tables
    spark = SparkSession.builder \
        .appName("FederatedLogsRetention") \
        .enableHiveSupport() \
        .getOrCreate()

    # Process each table with the same retention period
    results = {}
    for table_name in table_names:

        try:
            # Execute DELETE using Spark SQL
            delete_query = f"DELETE FROM glue_catalog.{database}.{table_name} WHERE timestamp < TIMESTAMP '{cutoff_str}'"
            print(f"[{table_name}] Executing: {delete_query}")
            spark.sql(delete_query)

            results[table_name] = 'SUCCESS'
            print(f"[{table_name}] ✓ Deletion completed successfully")

            # TODO: Report success to NGEP API

        except Exception as e:
            error_msg = str(e)
            results[table_name] = f'ERROR: {error_msg}'
            print(f"[{table_name}] ✗ Error: {error_msg}")

            # TODO: Report failure to NGEP API

            # Continue with other tables (don't fail fast)
            continue

    # Stop Spark session
    spark.stop()

    # Summary

    # Exit with error code if any failures
    failed = [t for t, s in results.items() if s != 'SUCCESS']
    if failed:
        print(f"{len(failed)} table(s) failed: {', '.join(failed)}")
        sys.exit(1)
    else:
        print(f" All {len(results)} table(s) processed successfully")

if __name__ == '__main__':
    main()
PYTHON
}

# AWS Glue Spark ETL Job for retention cleanup
resource "aws_glue_job" "retention" {
  count = local.is_retention_enabled ? 1 : 0

  name         = "${local.setup_naming_prefix}-retention-job"
  role_arn     = var.glue_service_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.s3_bucket_name}/${aws_s3_object.retention_script[0].key}"
    python_version  = "3"
  }

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 120
  max_retries       = 1

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-glue-datacatalog"          = "true"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--DATABASE_NAME"                    = var.glue_catalog_db_name
    "--TABLE_NAMES"                      = join(",", keys(local.all_tables))
  }
  depends_on = [aws_s3_object.retention_script]
}

# Glue Trigger to schedule retention job
# Runs daily at midnight UTC (00:00) to delete old data based on table retention_period settings
resource "aws_glue_trigger" "retention_schedule" {
  count = local.is_retention_enabled ? 1 : 0

  name     = "${local.setup_naming_prefix}-retention-schedule"
  type     = "SCHEDULED"
  schedule = "cron(0 0 * * ? *)"

  actions {
    job_name = aws_glue_job.retention[0].name
  }
}

# CloudWatch Log Group for retention job logs
resource "aws_cloudwatch_log_group" "retention_logs" {
  count = local.is_retention_enabled ? 1 : 0

  name              = "/aws-glue/jobs/${local.setup_naming_prefix}-retention-job"
  retention_in_days = 7
}
