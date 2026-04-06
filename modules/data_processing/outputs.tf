output "base_role_arn" {
  description = "ARN of the base IAM role. Annotate the K8s ServiceAccount with this value for IRSA."
  value       = aws_iam_role.base_role.arn
}

output "base_role_name" {
  description = "Name of the base IAM role."
  value       = aws_iam_role.base_role.name
}

output "fleet_id" {
  description = "Fleet identifier for this data processing instance."
  value       = local.fleet_id
}

output "data_processing_entity_id" {
  description = "NGEP data processing entity ID returned by NerdGraph. Read from the state file after first apply."
  value       = try(jsondecode(file("${path.module}/.entity_state.json")).entity_id, null)
}

output "cluster_memberships" {
  description = "Map of cluster keys to their fleet/role membership details."
  value = {
    for k, v in terraform_data.cluster_membership : k => v.input
  }
}
