variable "table_name" {
  description = "Name of the Iceberg table"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain log data"
  type        = number
}

variable "bucket_name" {
  description = "Name of the S3 bucket for table data"
  type        = string
}

variable "glue_db_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "glue_service_role_arn" {
  description = "ARN of the Glue service role for table maintenance"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for naming Iceberg table related AWS resources"
  type        = string
}
