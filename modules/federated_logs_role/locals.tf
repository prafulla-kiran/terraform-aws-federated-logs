locals {
  setup_naming_prefix = "newrelic-fed-logs-${var.setup_name}"

  # Logging Federated
  nr_source_account = "531948421264"

  # WARNING [DO NOT CHANGE]: Cross-repo contract with the NR hub. NRGlobalIAMRole's
  # inline policy only allows sts:AssumeRole on role ARNs matching
  # `newrelic-fed-logs-*-nr-query`. Editing this suffix will break cross-account
  # assumption at runtime.
  nr_reader_role_suffix = "nr-query"

}