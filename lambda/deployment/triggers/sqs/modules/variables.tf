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

variable "sqs_batch_size" {
  description = "Maximum number of records in each batch sent to the function"
  type        = number
  default     = 10
}

variable "sqs_maximum_batching_window_in_seconds" {
  description = "Maximum time in seconds to gather records before invoking the function (0 = invoke immediately)"
  type        = number
  default     = 0
}
