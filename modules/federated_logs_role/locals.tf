locals {
  setup_naming_prefix = "newrelic-fed-logs-${var.setup_name}"

  # Logging Federated
  nr_source_account = "531948421264"

  nr_graphql_endpoint = var.newrelic_region == "EU" ? "https://api.eu.newrelic.com/graphql" : (
    var.newrelic_region == "STAGING" ? "https://staging-api.newrelic.com/graphql" : "https://api.newrelic.com/graphql"
  )
}
