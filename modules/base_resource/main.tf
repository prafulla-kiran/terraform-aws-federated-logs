resource "aws_s3_bucket" "this" {
  bucket = "${var.naming_prefix}-${local.s3_bucket_name}"
  force_destroy = true
}

resource "aws_glue_catalog_database" "this" {
  name = "${var.naming_prefix}-${local.glue_catalog_db_name}"
  description = "Glue database containing NR resources for federated logs"
}

resource "aws_iam_role" "glue_service_role" {
  name = "${var.naming_prefix}-glue-service-role"
  permissions_boundary = "" 
  description = "Role for Glue Service to access S3 and manage its own resources"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "glue_service_policy" {
  name        = "${var.naming_prefix}-glue-service-policy"
  description = "Policy for Glue service to access S3 and manage its own resources"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "GlueServiceAccess"
        Effect   = "Allow"
        Action   = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchGetPartition"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "${aws_glue_catalog_database.this.arn}",
          "arn:aws:glue:*:*:table/${aws_glue_catalog_database.this.name}/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.this.arn}",
          "${aws_s3_bucket.this.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_attach" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_service_policy.arn
}