variable "region" {
  description = "AWS region where resources will be created. If not set, uses the provider's configured region."
  type        = string
  default     = null
}

variable "setup_name" {
  description = "A name for this federated logs setup, also used in resource naming."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.setup_name))
    error_message = "The setup_name must be all lowercase and alphanumeric, can contain hyphens but not as the first or last character, and must be between 3 and 26 characters long."
  }
}

variable "clusters" {
  description = "A map of cluster configurations for federated logging. Set auth_mode to 'irsa' (default) or 'pod_identity'. NOTE: 'pod_identity' requires the 'eks-pod-identity-agent' addon to be installed on each cluster — manage that in your EKS cluster module."
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
    condition     = alltrue([for c in var.clusters : c.auth_mode != "irsa" || (c.oidc_provider_arn != null && length(c.oidc_provider_arn) > 0)])
    error_message = "oidc_provider_arn must be set for clusters using auth_mode = 'irsa'."
  }

  validation {
    condition     = alltrue([for c in var.clusters : c.auth_mode != "pod_identity" || (c.cluster_name != null && length(c.cluster_name) > 0)])
    error_message = "cluster_name must be set for clusters using auth_mode = 'pod_identity'."
  }
}

#──────────────────────────────────────────────────────────────
# Optimizer configuration defaults (for both variables below):
#   orphan_file_deletion:
#     orphan_file_retention_period_in_days = 3
#     run_rate_in_hours                    = 24
#   snapshot_retention:
#     snapshot_retention_period_in_days    = 5
#     number_of_snapshots_to_retain        = 2
#     clean_expired_files                  = false
#     run_rate_in_hours                    = 24
#   compaction:
#     strategy                             = "binpack"
#     min_input_files                      = 5
#     delete_file_threshold                = 1
#──────────────────────────────────────────────────────────────

variable "default_table_setting" {
  description = "Settings for the primary federated log table, including Iceberg table parameters and optimizer configuration"
  type = object({
    table_parameters = optional(map(string), {})
    optimizer_configuration = optional(object({
      orphan_file_deletion = optional(object({
        orphan_file_retention_period_in_days = optional(number, 3)
        run_rate_in_hours                    = optional(number, 24)
      }), {})
      snapshot_retention = optional(object({
        snapshot_retention_period_in_days = optional(number, 5)
        number_of_snapshots_to_retain     = optional(number, 2)
        clean_expired_files               = optional(bool, false)
        run_rate_in_hours                 = optional(number, 24)
      }), {})
      compaction = optional(object({
        strategy              = optional(string, "binpack")
        min_input_files       = optional(number, 5)
        delete_file_threshold = optional(number, 1)
      }), {})
    }), {})
  })
  default = {}
}

variable "partition_tables" {
  description = "Map of additional partition tables. Each entry can override table_parameters and/or optimizer_configuration, or use {} for all defaults."
  type = map(object({
    table_parameters = optional(map(string), {})
    optimizer_configuration = optional(object({
      orphan_file_deletion = optional(object({
        orphan_file_retention_period_in_days = optional(number, 3)
        run_rate_in_hours                    = optional(number, 24)
      }), {})
      snapshot_retention = optional(object({
        snapshot_retention_period_in_days = optional(number, 5)
        number_of_snapshots_to_retain     = optional(number, 2)
        clean_expired_files               = optional(bool, false)
        run_rate_in_hours                 = optional(number, 24)
      }), {})
      compaction = optional(object({
        strategy              = optional(string, "binpack")
        min_input_files       = optional(number, 5)
        delete_file_threshold = optional(number, 1)
      }), {})
    }), {})
  }))
  default = {}
}

variable "newrelic_api_key" {
  description = "New Relic API key for NGEP API authentication (stored in AWS Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "retention_period" {
  description = "Data retention period for all tables. If set, enables automatic deletion of old data. Format: '<number> DAYS' (e.g., '7 DAYS', '90 DAYS'). If null, retention is disabled."
  type        = string
  default     = null

  validation {
    condition     = var.retention_period == null || can(regex("^[0-9]+ DAYS?$", var.retention_period))
    error_message = "retention_period must be in format '<number> DAYS' or '<number> DAY' (e.g., '7 DAYS', '1 DAY') or null to disable retention"
  }
}