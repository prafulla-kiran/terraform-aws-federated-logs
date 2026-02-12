# 1. Physical Storage
module "base" {
  source         = "./modules/base_resource"
  naming_prefix  = var.naming_prefix
  aws_account_id = var.aws_account_id
}

# 2. Log Partitions
module "partitions" {
  source                = "./modules/iceberg_table"
  for_each              = var.partitions # e.g. {"default" = 7, "security" = 30}
  naming_prefix         = var.naming_prefix
  table_name            = each.key
  retention_days        = each.value
  bucket_name           = module.base.bucket_name
  glue_db_name          = module.base.glue_db_name
  glue_service_role_arn = module.base.glue_role_arn
  aws_account_id        = var.aws_account_id
}

# 3. Writer Role (PCG)
module "writer" {
  source             = "./modules/pcg_iam"
  naming_prefix      = var.naming_prefix
  oidc_provider_arns = var.eks_oidc_arns
  oidc_urls          = var.eks_oidc_urls
  bucket_arn         = module.base.bucket_arn
  glue_db_name       = module.base.glue_db_name
  namespace          = var.namespace
  service_account    = var.service_account
}

# 4. Reader Role (New Relic)
module "reader" {
  source        = "./modules/nr_query_access"
  naming_prefix = var.naming_prefix
  bucket_name   = module.base.bucket_name
  glue_db_name  = module.base.glue_db_name
}