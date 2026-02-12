# Output values from the root module

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing federated logs"
  value       = module.base.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing federated logs"
  value       = module.base.bucket_arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.base.glue_db_name
}

output "glue_service_role_arn" {
  description = "ARN of the IAM role used by Glue for table maintenance"
  value       = module.base.glue_role_arn
}

output "pcg_writer_role_arn" {
  description = "ARN of the IAM role for PCG to write federated logs"
  value       = module.writer.writer_role_arn
}

output "nr_reader_role_arn" {
  description = "ARN of the IAM role for New Relic to query federated logs"
  value       = module.reader.reader_role_arn
}

output "iceberg_tables" {
  description = "Map of created Iceberg table names and their configurations"
  value = {
    for k, v in module.partitions : k => {
      table_name = v.table_name
      arn        = v.table_arn
    }
  }
}
