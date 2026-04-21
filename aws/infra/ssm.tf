# --- SSM Parameter Store — app secrets ---
#
# Set via TF_VAR_* env vars or terraform.tfvars (never commit values).
# ECS tasks read these at startup via the `secrets` block in the task definition.

resource "aws_ssm_parameter" "secret_key_base" {
  name  = "/${var.app_name}/${var.environment}/secret-key-base"
  type  = "SecureString"
  value = var.secret_key_base

  tags = { Name = "${local.name_prefix}-secret-key-base" }
}

resource "aws_ssm_parameter" "peek_api_key" {
  name  = "/${var.app_name}/${var.environment}/peek-api-key"
  type  = "SecureString"
  value = var.peek_api_key

  tags = { Name = "${local.name_prefix}-peek-api-key" }
}

resource "aws_ssm_parameter" "peek_app_secret" {
  name  = "/${var.app_name}/${var.environment}/peek-app-secret"
  type  = "SecureString"
  value = var.peek_app_secret

  tags = { Name = "${local.name_prefix}-peek-app-secret" }
}

resource "aws_ssm_parameter" "peek_app_id" {
  name  = "/${var.app_name}/${var.environment}/peek-app-id"
  type  = "SecureString"
  value = var.peek_app_id

  tags = { Name = "${local.name_prefix}-peek-app-id" }
}

resource "aws_ssm_parameter" "posthog_key" {
  name  = "/${var.app_name}/${var.environment}/posthog-key"
  type  = "SecureString"
  value = var.posthog_key

  tags = { Name = "${local.name_prefix}-posthog-key" }
}

resource "aws_ssm_parameter" "sentry_dsn" {
  name  = "/${var.app_name}/${var.environment}/sentry-dsn"
  type  = "SecureString"
  value = var.sentry_dsn

  tags = { Name = "${local.name_prefix}-sentry-dsn" }
}
