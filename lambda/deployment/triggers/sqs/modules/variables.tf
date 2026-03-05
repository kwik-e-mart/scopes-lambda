variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs to trigger this Lambda"
  type        = list(string)
  default     = []
}

variable "sqs_enabled" {
  description = "Whether SQS event source mappings are enabled (false during scope create, true after first deployment)"
  type        = bool
  default     = false
}
