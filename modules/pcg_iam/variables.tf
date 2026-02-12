variable "naming_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "nr-fed-logs"
}

variable "oidc_provider_arns" {
  description = "List of ARNs of the EKS OIDC providers for multiple K8s clusters"
  type        = list(string)

  validation {
    condition     = length(var.oidc_provider_arns) > 0
    error_message = "At least one OIDC provider ARN must be specified."
  }
}

variable "oidc_urls" {
  description = "List of URLs of the EKS OIDC providers (without https://) corresponding to oidc_provider_arns"
  type        = list(string)

  validation {
    condition     = length(var.oidc_urls) > 0
    error_message = "At least one OIDC URL must be specified."
  }
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket for log storage"
  type        = string
}

variable "glue_db_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the PCG service account"
  type        = string
  default     = "pcg-system"
}

variable "service_account" {
  description = "Kubernetes service account name for PCG"
  type        = string
  default     = "pcg-writer"
}
