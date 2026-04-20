data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  s3_bucket_arn  = "arn:aws:s3:::${var.s3_bucket_name}"
  s3_object_arn  = "arn:aws:s3:::${var.s3_bucket_name}/*"
  glue_catalog   = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:catalog"
  glue_db_arn    = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}"
  glue_table_arn = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"

  glue_role_name       = element(split("/", var.glue_service_role_arn), length(split("/", var.glue_service_role_arn)) - 1)
  pcg_writer_role_name = element(split("/", var.pcg_writer_role_arn), length(split("/", var.pcg_writer_role_arn)) - 1)
  nr_reader_role_name  = element(split("/", var.nr_reader_role_arn), length(split("/", var.nr_reader_role_arn)) - 1)
}

# ──────────────────────────────────────────────────────────────
# Resource Existence Checks
# ──────────────────────────────────────────────────────────────

check "s3_bucket_exists" {
  data "aws_s3_bucket" "this" {
    bucket = var.s3_bucket_name
  }

  assert {
    condition     = data.aws_s3_bucket.this.id == var.s3_bucket_name
    error_message = "S3 bucket '${var.s3_bucket_name}' does not exist or is not accessible."
  }
}

# Note: There is no aws_glue_catalog_database data source in the AWS provider.
# Glue database existence is implicitly validated by the IAM policy simulation
# checks, which target the database ARN. If the DB doesn't exist, permission
# simulation will still pass (it evaluates policy, not resource existence),
# but the table-level checks via Athena (Layer 3 script) will catch this.

# ──────────────────────────────────────────────────────────────
# IAM Role Existence Checks
# ──────────────────────────────────────────────────────────────

check "glue_service_role_exists" {
  data "aws_iam_role" "glue" {
    name = local.glue_role_name
  }

  assert {
    condition     = data.aws_iam_role.glue.arn == var.glue_service_role_arn
    error_message = "Glue service role does not exist or ARN mismatch. Expected: ${var.glue_service_role_arn}"
  }
}

check "pcg_writer_role_exists" {
  data "aws_iam_role" "pcg" {
    name = local.pcg_writer_role_name
  }

  assert {
    condition     = data.aws_iam_role.pcg.arn == var.pcg_writer_role_arn
    error_message = "PCG writer role does not exist or ARN mismatch. Expected: ${var.pcg_writer_role_arn}"
  }
}

check "nr_reader_role_exists" {
  data "aws_iam_role" "nr" {
    name = local.nr_reader_role_name
  }

  assert {
    condition     = data.aws_iam_role.nr.arn == var.nr_reader_role_arn
    error_message = "NR reader role does not exist or ARN mismatch. Expected: ${var.nr_reader_role_arn}"
  }
}

# ──────────────────────────────────────────────────────────────
# Trust Policy Structure Checks
# ──────────────────────────────────────────────────────────────

check "glue_role_trusts_glue_service" {
  data "aws_iam_role" "glue_trust" {
    name = local.glue_role_name
  }

  assert {
    condition     = can(regex("glue\\.amazonaws\\.com", data.aws_iam_role.glue_trust.assume_role_policy))
    error_message = "Glue service role trust policy does not allow glue.amazonaws.com. Table optimization will not function."
  }
}

check "pcg_writer_has_oidc_federation" {
  data "aws_iam_role" "pcg_trust" {
    name = local.pcg_writer_role_name
  }

  assert {
    condition     = can(regex("AssumeRoleWithWebIdentity", data.aws_iam_role.pcg_trust.assume_role_policy))
    error_message = "PCG writer role trust policy missing OIDC federation (sts:AssumeRoleWithWebIdentity). EKS pods cannot assume this role."
  }
}

# ──────────────────────────────────────────────────────────────
# OIDC Provider Trust Policy Check
#
# Verifies that each OIDC provider ARN from the clusters map
# appears in the PCG writer role's trust policy. If a wrong ARN
# was provided, pods from that cluster will silently fail
# AssumeRoleWithWebIdentity.
# ──────────────────────────────────────────────────────────────

check "pcg_writer_trusts_all_clusters" {
  data "aws_iam_role" "pcg_oidc_check" {
    name = local.pcg_writer_role_name
  }

  assert {
    condition = length(var.clusters) == 0 || alltrue([
      for k, v in var.clusters :
      can(regex(replace(v.oidc_provider_arn, ".", "\\."), data.aws_iam_role.pcg_oidc_check.assume_role_policy))
    ])
    error_message = "PCG writer role trust policy does not reference all cluster OIDC provider ARNs. Some EKS clusters may not be able to assume this role. Verify the oidc_provider_arn values in your clusters map."
  }
}

# ──────────────────────────────────────────────────────────────
# OIDC Provider Existence Check
#
# Verifies that each cluster's OIDC provider ARN actually exists
# in the AWS account. A typo or deleted OIDC provider will cause
# AssumeRoleWithWebIdentity to fail at runtime with a cryptic
# "Not authorized to perform sts:AssumeRoleWithWebIdentity" error.
#
# Requires: iam:GetOpenIDConnectProvider
# Gated by: var.enable_oidc_validation (default false)
# ──────────────────────────────────────────────────────────────

locals {
  # Extract the OIDC provider URL from each ARN for lookup.
  # ARN format: arn:aws:iam::ACCOUNT:oidc-provider/ISSUER_URL
  oidc_arns = var.enable_oidc_validation ? {
    for k, v in var.clusters : k => v.oidc_provider_arn
  } : {}
}

data "aws_iam_openid_connect_provider" "cluster" {
  for_each = local.oidc_arns
  arn      = each.value
}

check "oidc_providers_exist" {
  assert {
    condition = !var.enable_oidc_validation || alltrue([
      for k, v in local.oidc_arns :
      data.aws_iam_openid_connect_provider.cluster[k].arn == v
    ])
    error_message = "One or more OIDC provider ARNs from the clusters map do not exist in this AWS account. EKS pods will not be able to assume the PCG writer role."
  }
}

check "nr_reader_has_external_id" {
  data "aws_iam_role" "nr_trust" {
    name = local.nr_reader_role_name
  }

  assert {
    condition     = can(regex("sts:ExternalId", data.aws_iam_role.nr_trust.assume_role_policy))
    error_message = "NR reader role trust policy missing ExternalId condition. This creates a confused deputy risk for cross-account access."
  }
}
