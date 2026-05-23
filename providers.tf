terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">= 3.62.0"
    }
  }
}

# The newrelic provider's region is tied to var.newrelic_region so that one
# input ("US" | "EU" | "STAGING") drives both the provider's API endpoint
# AND the Python helper scripts in submodules that compute their own
# GraphQL endpoint from the same variable.
provider "newrelic" {
  region = var.newrelic_region
}

