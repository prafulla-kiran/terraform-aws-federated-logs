variable "s3_bucket_name" {
  description = "Name of the S3 bucket containing logs"
  type        = string
}

variable "glue_catalog_db_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created. If not set, uses the provider's configured region."
  type        = string
  default     = null
}

variable "base_role_arn" {
  description = "ARN of the fleet-level PCG base role (from the data_processing module). The pcg-writer role trusts this role via ABAC tag matching."
  type        = string
}

variable "pcg_instance_name" {
  description = "Fleet name used as the PCG_Instance ABAC tag value. Must match the name used in the data_processing module."
  type        = string
}

variable "setup_name" {
  description = "A name for this federated logs setup, also used in resource naming."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.setup_name))
    error_message = "The setup_name must be all lowercase and alphanumeric, can contain hyphens but not as the first or last character, and must be between 3 and 26 characters long."
  }
}
