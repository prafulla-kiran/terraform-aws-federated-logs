# Input variables for the root module

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "naming_prefix" {
  description = "Prefix for naming Federated logs related AWS resources"
  type        = string
  default     = "nr-fed-logs"
}

variable "aws_account_id" {
  description = "AWS account ID where resources will be deployed"
  type        = string
}

variable "partitions" {
  description = "Map of partition names to retention days for log tables"
  type        = map(number)
  default = {
    default  = 7
    security = 30
  }
}

variable "eks_oidc_arns" {
  description = "List of ARNs of the EKS OIDC providers for PCG writer role authentication across multiple K8s clusters"
  type        = list(string)
}

variable "eks_oidc_urls" {
  description = "List of URLs of the EKS OIDC providers (without https://) for PCG writer role authentication, corresponding to eks_oidc_arns"
  type        = list(string)
}

variable "namespace" {
  description = "Kubernetes namespace for the PCG service account"
  type        = string
  default     = "newrelic"
}

variable "service_account" {
  description = "Kubernetes service account name for PCG"
  type        = string
}