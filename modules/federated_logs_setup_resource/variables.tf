variable "setup_name" {
  description = "A name for this federated logs setup, also used in resource naming."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.setup_name))
    error_message = "The setup_name must be all lowercase and alphanumeric, can contain hyphens but not as the first or last character, and must be between 3 and 26 characters long."
  }
}

variable "region" {
  description = "AWS region where resources will be created. If not set, uses the provider's configured region."
  type        = string
  default     = null
}

variable "fleet_entity_guid" {
  description = "NGEP entity GUID of the fleet. Used to look up the SQS queue ARN and base role ARN from the AWS Connection Entity."
  type        = string
}

variable "newrelic_region" {
  description = "New Relic region: 'US', 'EU', or 'STAGING'."
  type        = string
  default     = "US"
  validation {
    condition     = contains(["US", "EU", "STAGING"], var.newrelic_region)
    error_message = "newrelic_region must be 'US', 'EU', or 'STAGING'."
  }
}

variable "flink_assume_role_arn" {
  description = "IAM role ARN injected into EventBridge SQS message envelope. The Flink commit worker will AssumeRole into this role."
  type        = string
  default     = ""
}
