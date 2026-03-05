# Event Source Mapping: one per queue ARN
resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = toset(var.sqs_queue_arns)

  event_source_arn = each.value
  function_name    = local.lambda_alias_arn
  enabled          = var.sqs_enabled

  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_maximum_batching_window_in_seconds

  function_response_types = ["ReportBatchItemFailures"]
}
