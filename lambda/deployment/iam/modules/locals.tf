locals {
  # Module identifier
  iam_module_name = "iam"

  # Determine the role ARN to use
  lambda_role_arn = var.iam_create_role ? aws_iam_role.lambda[0].arn : var.lambda_role_arn

  # Default tags
  iam_default_tags = merge(var.iam_resource_tags_json, {
    ManagedBy = "terraform"
    Module    = local.iam_module_name
  })

  # Basic Lambda execution policy ARN
  lambda_basic_execution_policy = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

  # VPC access policy ARN
  lambda_vpc_access_policy = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"

  # Managed policies to attach
  iam_managed_policies = var.iam_vpc_enabled ? [
    local.lambda_basic_execution_policy,
    local.lambda_vpc_access_policy
  ] : [
    local.lambda_basic_execution_policy
  ]
}
