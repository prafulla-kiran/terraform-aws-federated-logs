data "aws_region" "current" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# ── Base Role ────────────────────────────────────────────────────────────────
# Fleet-level IAM role authenticated via OIDC (IRSA) or Pod Identity.
# Has NO direct S3/Glue permissions — it can only assume per-setup pcg-writer
# roles via the ABAC inline policy below.

resource "aws_iam_role" "base_role" {
  name        = "${local.naming_prefix}-base"
  description = "Fleet-level base role for PCG. Authenticates via EKS and assumes per-setup writer roles via ABAC."

  assume_role_policy = local.auth_mode == "irsa" ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      for key, config in var.clusters : {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = config.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(config.oidc_provider_arn, "/^arn:aws:iam::.*:oidc-provider//", "")}:sub" = "system:serviceaccount:${config.k8s_namespace}:${config.k8s_service_account_name}"
            "${replace(config.oidc_provider_arn, "/^arn:aws:iam::.*:oidc-provider//", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = ["sts:AssumeRole", "sts:TagSession"]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes-namespace" = [for c in var.clusters : c.k8s_namespace]
          }
        }
      }
    ]
  })

  tags = {
    PCG_Instance = var.name
  }
}

# ABAC wildcard policy: allows assuming any pcg-writer role in any account
# where the role's PCG_Instance tag matches this base role's PCG_Instance tag.
resource "aws_iam_role_policy" "abac_assume_policy" {
  name = "${local.naming_prefix}-abac-assume"
  role = aws_iam_role.base_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::*:role/newrelic-fed-logs-*-pcg-writer"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/PCG_Instance" = "$${aws:PrincipalTag/PCG_Instance}"
          }
        }
      }
    ]
  })
}

# Pod Identity: bind base role to each cluster's service account
resource "aws_eks_pod_identity_association" "base_role" {
  for_each = { for k, v in var.clusters : k => v if local.auth_mode == "pod_identity" }

  cluster_name    = each.value.cluster_name
  namespace       = each.value.k8s_namespace
  service_account = each.value.k8s_service_account_name
  role_arn        = aws_iam_role.base_role.arn
}

# ── NGEP: AWS Connection Entity ───────────────────────────────────────────────
# Creates a New Relic AWS Connection Entity that stores the base role ARN
# as the credential. This entity is referenced by the FederatedLogsDataProcessingEntity
# (see TODO below).

resource "null_resource" "aws_connection_entity" {
  # nr_api_key is stored in triggers so destroy provisioner can access it via self.triggers.
  triggers = {
    role_arn      = aws_iam_role.base_role.arn
    nr_account_id = var.newrelic_account_id
    entity_name   = "${local.naming_prefix}-aws-connection"
    nr_endpoint   = local.nr_graphql_endpoint
    nr_api_key    = var.newrelic_api_key
  }

  provisioner "local-exec" {
    environment = {
      ROLE_ARN      = aws_iam_role.base_role.arn
      ENTITY_NAME   = "${local.naming_prefix}-aws-connection"
      NR_ACCOUNT_ID = var.newrelic_account_id
      NR_API_KEY    = var.newrelic_api_key
      NR_ENDPOINT   = local.nr_graphql_endpoint
      STATE_FILE    = "${path.module}/.aws_connection_entity_id"
      ERROR_FILE    = "${path.module}/.aws_connection_entity_error"
    }
    command = <<-EOT
      set -e
      RESPONSE=$(python3 - <<'PYEOF'
import json, urllib.request, os, sys

endpoint   = os.environ['NR_ENDPOINT']
api_key    = os.environ['NR_API_KEY']
role_arn   = os.environ['ROLE_ARN']
name       = os.environ['ENTITY_NAME']
acct_id    = os.environ['NR_ACCOUNT_ID']
state_file = os.environ['STATE_FILE']
error_file = os.environ['ERROR_FILE']

mutation = """
mutation {
  entityManagementCreateAwsConnection(
    awsConnectionEntity: {
      name: "%s",
      credential: {assumeRole: {roleArn: "%s"}},
      scope: {id: "%s", type: ORGANIZATION}
    }
  ) {
    entity { id }
  }
}
""" % (name, role_arn, acct_id)

payload = json.dumps({"query": mutation}).encode()
req = urllib.request.Request(endpoint, data=payload, headers={
  "Content-Type": "application/json",
  "API-Key": api_key
})
try:
    resp = json.loads(urllib.request.urlopen(req).read())
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8", errors="replace")
    msg = "HTTP %d %s\nResponse: %s" % (e.code, e.reason, body)
    open(error_file, "w").write(msg)
    print(msg, file=sys.stderr)
    sys.exit(1)

if "errors" in resp:
    msg = "GraphQL errors: " + json.dumps(resp["errors"], indent=2)
    open(error_file, "w").write(msg)
    print(msg, file=sys.stderr)
    sys.exit(1)

entity_id = resp['data']['entityManagementCreateAwsConnection']['entity']['id']
with open(state_file, 'w') as f:
    f.write(entity_id)
print("Created AWS Connection Entity: " + entity_id)
PYEOF
      )
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      NR_API_KEY  = self.triggers.nr_api_key
      NR_ENDPOINT = self.triggers.nr_endpoint
      STATE_FILE  = "${path.module}/.aws_connection_entity_id"
    }
    command = <<-EOT
      set -e
      python3 - <<'PYEOF'
import json, urllib.request, os, sys

endpoint   = os.environ['NR_ENDPOINT']
api_key    = os.environ['NR_API_KEY']
state_file = os.environ['STATE_FILE']

if not os.path.exists(state_file):
    print("No entity ID file found, skipping delete.")
    sys.exit(0)

with open(state_file) as f:
    entity_id = f.read().strip()

if not entity_id:
    print("Empty entity ID, skipping delete.")
    sys.exit(0)

# TODO: Replace with the correct NerdGraph delete mutation once confirmed.
# mutation = """
# mutation {
#   entityManagementDeleteEntity(id: "%s") { deletedEntityId }
# }
# """ % entity_id

print("TODO: delete AWS Connection Entity %s — mutation not yet confirmed." % entity_id)
os.remove(state_file)
PYEOF
    EOT
  }
}

# TODO: Create FederatedLogsDataProcessingEntity once mutation is available.
# This entity is fleet-level and references the AWS Connection Entity created above.