# IAM Role for Lambda execution
resource "aws_iam_role" "lambda" {
  count = var.iam_create_role ? 1 : 0

  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.iam_default_tags
}

# Attach managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  count = var.iam_create_role ? length(local.iam_managed_policies) : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = local.iam_managed_policies[count.index]
}

# Attach custom inline policies
resource "aws_iam_role_policy" "custom" {
  count = var.iam_create_role ? length(var.iam_role_policies) : 0

  name   = var.iam_role_policies[count.index].name
  role   = aws_iam_role.lambda[0].id
  policy = var.iam_role_policies[count.index].policy
}

# Secrets Manager read access (for parameters strategy = secretsmanager)
resource "aws_iam_role_policy" "secrets_manager" {
  count = var.iam_create_role && var.iam_secrets_manager_secret_arn != "" ? 1 : 0

  name = "secrets-manager-parameters-read"
  role = aws_iam_role.lambda[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.iam_secrets_manager_secret_arn
      }
    ]
  })
}
