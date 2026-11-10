provider "aws" {
  region = var.aws_region

  skip_credentials_validation = var.plan_only
  skip_metadata_api_check     = var.plan_only
  skip_requesting_account_id  = var.plan_only
  access_key                  = var.plan_only ? "plan-only" : null
  secret_key                  = var.plan_only ? "plan-only" : null

  default_tags {
    tags = local.tags
  }
}
