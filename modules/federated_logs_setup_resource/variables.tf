variable "naming_prefix" {
  description = "The prefix for resource names."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "setup_name" {
  description = "A name for this federated logs setup, used in tagging and resource naming."
  type        = string
}