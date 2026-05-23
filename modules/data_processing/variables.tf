variable "data_processing_module_name" {
  description = "Name for this data processing setup. Used in resource naming."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.data_processing_module_name))
    error_message = "data_processing_module_name must be lowercase alphanumeric with hyphens (not first/last), 3–26 chars."
  }
}

variable "clusters" {
  description = "Map of EKS cluster configs used to build the base role trust policy. All clusters must share the same auth_mode."
  type = map(object({
    auth_mode                = optional(string, "irsa") # "irsa" or "pod_identity"
    k8s_namespace            = string
    k8s_service_account_name = string
    oidc_provider_arn        = optional(string) # Required when auth_mode = "irsa"
    cluster_name             = optional(string) # Required when auth_mode = "pod_identity"
  }))

  validation {
    condition     = alltrue([for c in var.clusters : length(c.k8s_namespace) > 0 && length(c.k8s_service_account_name) > 0])
    error_message = "k8s_namespace and k8s_service_account_name must be non-empty for each cluster."
  }

  validation {
    condition     = alltrue([for c in var.clusters : contains(["irsa", "pod_identity"], c.auth_mode)])
    error_message = "auth_mode must be either 'irsa' or 'pod_identity'."
  }

  validation {
    condition     = length(distinct([for c in var.clusters : c.auth_mode])) <= 1
    error_message = "All clusters must use the same auth_mode. Mixing 'irsa' and 'pod_identity' is not supported."
  }

  validation {
    # try() is the null-safe form: terraform doesn't short-circuit `||`/`&&`
    # inside validations, so the previous `c.X != null && length(c.X) > 0`
    # blew up with length(null) on the other auth_mode (where X is legitimately null).
    condition     = alltrue([for c in var.clusters : c.auth_mode != "irsa" || try(length(c.oidc_provider_arn) > 0, false)])
    error_message = "oidc_provider_arn must be set for clusters using auth_mode = 'irsa'."
  }

  validation {
    condition     = alltrue([for c in var.clusters : c.auth_mode != "pod_identity" || try(length(c.cluster_name) > 0, false)])
    error_message = "cluster_name must be set for clusters using auth_mode = 'pod_identity'."
  }
}

variable "fleet_entity_guid" {
  description = "NGEP entity GUID of the fleet (e.g. FederatedLogsDataProcessingEntity). A relationship of type HAS_FED_LOGS_BASE_ROLE will be created from this entity to the AWS Connection Entity."
  type        = string
}

variable "newrelic_org_id" {
  description = "New Relic organization ID (GUID) used to scope NGEP entities at the ORGANIZATION level."
  type        = string
}

variable "newrelic_region" {
  description = "New Relic region: 'US', 'EU', or 'STAGING'. Defaults to STAGING for parity with the top-level + role module defaults — the federatedLogs* wrapper APIs are mocked on prod, so staging is the active integration target. Override once the wrapper API is live in prod."
  type        = string
  default     = "STAGING"
  validation {
    condition     = contains(["US", "EU", "STAGING"], var.newrelic_region)
    error_message = "newrelic_region must be 'US', 'EU', or 'STAGING'."
  }
}
