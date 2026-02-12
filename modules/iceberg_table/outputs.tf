output "table_name" {
  description = "Name of the Glue catalog table"
  value       = aws_glue_catalog_table.this.name
}

output "table_arn" {
  description = "ARN of the Glue catalog table"
  value       = aws_glue_catalog_table.this.arn
}