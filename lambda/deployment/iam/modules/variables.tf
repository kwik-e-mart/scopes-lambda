variable "iam_role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "iam_create_role" {
  description = "Whether to create the IAM role"
  type        = bool
  default     = false
}

variable "iam_role_policies" {
  description = "List of IAM policies to attach"
  type = list(object({
    name   = string
    policy = string
  }))
  default = []
}

variable "iam_vpc_enabled" {
  description = "Whether Lambda needs VPC access"
  type        = bool
  default     = false
}

variable "iam_role_entity" {
  description = "Role entity type (scope or deployment)"
  type        = string
  default     = "scope"
}

variable "iam_resource_tags_json" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

variable "iam_secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN for parameters (empty to disable)"
  type        = string
  default     = ""
}

variable "lambda_role_arn" {
  description = "Existing Lambda role ARN (when not creating)"
  type        = string
  default     = ""
}
