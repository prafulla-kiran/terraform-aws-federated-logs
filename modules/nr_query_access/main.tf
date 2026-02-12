resource "aws_iam_role" "this" {
  name        = "${var.naming_prefix}-nr-query-role"
  description = "Cross-account role for New Relic Query Engine to read logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        # The official NR Account provided in your POC
        AWS = "arn:aws:iam::${local.nr_source_account}:user/federated-logs-user"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = local.nr_external_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "reader_policy" {
  name = "${var.naming_prefix}-nr-query-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Sid    = "GlueCatalogReadOnly"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
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

output "reader_role_arn" {
  value = aws_iam_role.this.arn
}