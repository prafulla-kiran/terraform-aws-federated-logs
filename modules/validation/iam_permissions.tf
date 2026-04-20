# ──────────────────────────────────────────────────────────────
# IAM Policy Simulation Checks
#
# These use the IAM Policy Simulator API to verify that each role
# has the correct permissions — both positive (can do what it needs)
# and negative (cannot do what it shouldn't).
#
# Requires the Terraform execution identity to have:
#   iam:SimulatePrincipalPolicy on the roles being tested.
#
# Set var.enable_permission_checks = false to skip these checks
# if the permission cannot be granted.
# ──────────────────────────────────────────────────────────────

# ──────────────────────────
# PCG Writer — POSITIVE
# ──────────────────────────

data "aws_iam_principal_policy_simulation" "pcg_writer_s3_write" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
  policy_source_arn = var.pcg_writer_role_arn
  resource_arns     = [local.s3_object_arn]
}

check "pcg_writer_can_write_s3" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.pcg_writer_s3_write[0].all_allowed : true
    error_message = "PCG writer role CANNOT write to S3 bucket '${var.s3_bucket_name}'. Log ingestion will fail."
  }
}

data "aws_iam_principal_policy_simulation" "pcg_writer_glue_access" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["glue:GetTable", "glue:UpdateTable", "glue:GetDatabase"]
  policy_source_arn = var.pcg_writer_role_arn
  resource_arns     = [local.glue_catalog, local.glue_db_arn, local.glue_table_arn]
}

check "pcg_writer_can_update_glue" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.pcg_writer_glue_access[0].all_allowed : true
    error_message = "PCG writer role CANNOT update Glue tables. Iceberg metadata commits will fail."
  }
}

# ──────────────────────────
# PCG Writer — NEGATIVE
# ──────────────────────────

data "aws_iam_principal_policy_simulation" "pcg_writer_no_delete_bucket" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["s3:DeleteBucket"]
  policy_source_arn = var.pcg_writer_role_arn
  resource_arns     = [local.s3_bucket_arn]
}

check "pcg_writer_cannot_delete_bucket" {
  assert {
    condition     = var.enable_permission_checks ? !data.aws_iam_principal_policy_simulation.pcg_writer_no_delete_bucket[0].all_allowed : true
    error_message = "PCG writer role CAN delete the S3 bucket — policy is too permissive!"
  }
}

data "aws_iam_principal_policy_simulation" "pcg_writer_no_delete_glue_table" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["glue:DeleteTable", "glue:DeleteDatabase"]
  policy_source_arn = var.pcg_writer_role_arn
  resource_arns     = [local.glue_db_arn, local.glue_table_arn]
}

check "pcg_writer_cannot_delete_glue_resources" {
  assert {
    condition     = var.enable_permission_checks ? !data.aws_iam_principal_policy_simulation.pcg_writer_no_delete_glue_table[0].all_allowed : true
    error_message = "PCG writer role CAN delete Glue tables/database — policy is too permissive!"
  }
}

# ──────────────────────────
# NR Reader — POSITIVE
# ──────────────────────────

data "aws_iam_principal_policy_simulation" "nr_reader_s3_read" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["s3:GetObject", "s3:ListBucket"]
  policy_source_arn = var.nr_reader_role_arn
  resource_arns     = [local.s3_bucket_arn, local.s3_object_arn]
}

check "nr_reader_can_read_s3" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.nr_reader_s3_read[0].all_allowed : true
    error_message = "NR reader role CANNOT read S3 bucket '${var.s3_bucket_name}'. New Relic queries will return no data."
  }
}

data "aws_iam_principal_policy_simulation" "nr_reader_glue_read" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["glue:GetTable", "glue:GetTables", "glue:GetDatabase", "glue:GetPartitions", "glue:BatchGetPartition"]
  policy_source_arn = var.nr_reader_role_arn
  resource_arns     = [local.glue_catalog, local.glue_db_arn, local.glue_table_arn]
}

check "nr_reader_can_read_glue" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.nr_reader_glue_read[0].all_allowed : true
    error_message = "NR reader role CANNOT read Glue catalog. New Relic queries will fail."
  }
}

# ──────────────────────────
# NR Reader — NEGATIVE
# ──────────────────────────

data "aws_iam_principal_policy_simulation" "nr_reader_no_s3_write" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["s3:PutObject", "s3:DeleteObject"]
  policy_source_arn = var.nr_reader_role_arn
  resource_arns     = [local.s3_object_arn]
}

check "nr_reader_cannot_write_s3" {
  assert {
    condition     = var.enable_permission_checks ? !data.aws_iam_principal_policy_simulation.nr_reader_no_s3_write[0].all_allowed : true
    error_message = "NR reader role CAN write/delete S3 objects — policy is too permissive! Reader should be read-only."
  }
}

data "aws_iam_principal_policy_simulation" "nr_reader_no_glue_modify" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["glue:UpdateTable", "glue:DeleteTable", "glue:CreateTable"]
  policy_source_arn = var.nr_reader_role_arn
  resource_arns     = [local.glue_table_arn]
}

check "nr_reader_cannot_modify_glue" {
  assert {
    condition     = var.enable_permission_checks ? !data.aws_iam_principal_policy_simulation.nr_reader_no_glue_modify[0].all_allowed : true
    error_message = "NR reader role CAN modify Glue tables — policy is too permissive! Reader should be read-only."
  }
}

# ──────────────────────────
# Glue Service Role — POSITIVE
# ──────────────────────────

data "aws_iam_principal_policy_simulation" "glue_role_s3_access" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
  policy_source_arn = var.glue_service_role_arn
  resource_arns     = [local.s3_bucket_arn, local.s3_object_arn]
}

check "glue_role_can_access_s3" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.glue_role_s3_access[0].all_allowed : true
    error_message = "Glue service role CANNOT access S3. Table compaction, retention, and orphan deletion will fail."
  }
}

data "aws_iam_principal_policy_simulation" "glue_role_glue_access" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["glue:GetTable", "glue:UpdateTable", "glue:GetDatabase"]
  policy_source_arn = var.glue_service_role_arn
  resource_arns     = [local.glue_catalog, local.glue_db_arn, local.glue_table_arn]
}

check "glue_role_can_access_glue" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.glue_role_glue_access[0].all_allowed : true
    error_message = "Glue service role CANNOT access Glue catalog. Table optimization will fail."
  }
}

data "aws_iam_principal_policy_simulation" "glue_role_cloudwatch" {
  count             = var.enable_permission_checks ? 1 : 0
  action_names      = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
  policy_source_arn = var.glue_service_role_arn
  resource_arns     = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*:*"]
}

check "glue_role_can_write_logs" {
  assert {
    condition     = var.enable_permission_checks ? data.aws_iam_principal_policy_simulation.glue_role_cloudwatch[0].all_allowed : true
    error_message = "Glue service role CANNOT write CloudWatch logs. Optimizer job diagnostics will be unavailable."
  }
}
