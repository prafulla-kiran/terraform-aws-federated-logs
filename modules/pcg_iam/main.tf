resource "aws_iam_role" "this" {
  name        = "${var.naming_prefix}-pcg-writer-role"
  description = "Role for PCG pods in EKS to write federated logs"

  lifecycle {
    precondition {
      condition     = length(var.oidc_provider_arns) == length(var.oidc_urls)
      error_message = "The number of OIDC URLs must match the number of OIDC provider ARNs. Got ${length(var.oidc_provider_arns)} ARNs and ${length(var.oidc_urls)} URLs."
    }
  }

  # Trust policy for EKS OIDC - supports multiple K8s clusters
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for idx, oidc_arn in var.oidc_provider_arns : {
        Effect = "Allow"
        Principal = {
          Federated = oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Restrict to a specific namespace and service account for security
            "${var.oidc_urls[idx]}:sub" : "system:serviceaccount:${var.namespace}:${var.service_account}"
            "${var.oidc_urls[idx]}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "writer_policy" {
  name = "${var.naming_prefix}-pcg-writer-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WriteAccess"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      },
      {
        Sid    = "GlueCatalogUpdate"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:UpdateTable",
          "glue:CreateTable"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/${var.glue_db_name}",
          "arn:aws:glue:*:*:table/${var.glue_db_name}/*"
        ]
      }
    ]
  })
}

output "writer_role_arn" {
  value = aws_iam_role.this.arn
}