variable "name" {
  description = "Name for this data processing instance, used in IAM resource naming."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.name))
    error_message = "name must be 3-26 chars, lowercase alphanumeric and hyphens (no leading/trailing hyphen)."
  }
}

variable "clusters" {
  description = "Map of EKS clusters forming the processing fleet. Each cluster runs a PCG instance whose pod assumes the base role via IRSA/Pod Identity."
  type = map(object({
    k8s_namespace            = string
    k8s_service_account_name = string
    oidc_provider_arn        = string
  }))

  validation {
    condition     = length(var.clusters) > 0
    error_message = "At least one cluster must be provided."
  }

  validation {
    condition     = alltrue([for c in var.clusters : length(c.k8s_namespace) > 0 && length(c.k8s_service_account_name) > 0 && length(c.oidc_provider_arn) > 0])
    error_message = "All fields (k8s_namespace, k8s_service_account_name, oidc_provider_arn) must be non-empty for each cluster."
  }
}

variable "auth_mode" {
  description = "Authentication mode for the NGEP data processing entity."
  type        = string
  default     = "IAM_ROLE"
  validation {
    condition     = contains(["IAM_ROLE"], var.auth_mode)
    error_message = "auth_mode must be one of: IAM_ROLE."
  }
}

variable "newrelic_account_id" {
  description = "New Relic account ID for NGEP entity registration."
  type        = number
}

variable "newrelic_user_api_key" {
  description = "New Relic User API key (NerdGraph) for entity registration."
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "New Relic region: US or EU."
  type        = string
  default     = "US"
  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "newrelic_region must be US or EU."
  }
}
