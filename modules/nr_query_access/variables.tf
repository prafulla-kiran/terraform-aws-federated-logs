variable "naming_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "nr-fed-logs"
}

variable "bucket_name" {
  description = "Name of the S3 bucket containing logs"
  type        = string
}

variable "glue_db_name" {
  description = "Name of the Glue catalog database"
  type        = string
}
