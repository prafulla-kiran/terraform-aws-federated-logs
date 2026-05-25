locals {
  naming_prefix = "newrelic-fed-logs-fleet-${var.data_processing_module_name}"

  auth_mode = length(var.clusters) > 0 ? values(var.clusters)[0].auth_mode : "irsa"

  nr_graphql_endpoint = var.newrelic_region == "EU" ? "https://api.eu.newrelic.com/graphql" : (
    var.newrelic_region == "STAGING" ? "https://staging-api.newrelic.com/graphql" : "https://api.newrelic.com/graphql"
  )

  # ArnLike pattern used in the SQS queue resource policy to scope allowed EventBridge sources.
  # Matches every per-setup rule that follows the newrelic-fed-logs-*-iceberg-file-created convention,
  # locked to this AWS account so cross-account rules cannot send to the queue.
  sqs_eventbridge_source_arn_pattern = "arn:aws:events:*:${data.aws_caller_identity.current.account_id}:rule/newrelic-fed-logs-*-iceberg-file-created"
}
