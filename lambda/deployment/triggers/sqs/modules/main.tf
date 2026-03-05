# Event Source Mapping: one per queue ARN
resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = toset(var.sqs_queue_arns)

  event_source_arn = each.value
  function_name    = local.lambda_alias_arn
  enabled          = var.sqs_enabled

  function_response_types = ["ReportBatchItemFailures"]
}

# Lambda permission: allow each SQS queue to invoke the function
resource "aws_lambda_permission" "sqs" {
  for_each = toset(var.sqs_queue_arns)

  statement_id  = "AllowSQSTrigger${md5(each.value)}"
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_function_name
  qualifier     = local.lambda_main_alias_name
  principal     = "sqs.amazonaws.com"
  source_arn    = each.value
}
