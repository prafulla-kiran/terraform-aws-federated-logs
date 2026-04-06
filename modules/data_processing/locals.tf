locals {
  naming_prefix = "nr-fed-logs-${var.name}"

  # Stable fleet identifier — one fleet per data_processing instance.
  fleet_id = "${var.name}-fleet"

  nr_endpoint = var.newrelic_region == "EU" ? "https://api.eu.newrelic.com/graphql" : "https://api.newrelic.com/graphql"
}
