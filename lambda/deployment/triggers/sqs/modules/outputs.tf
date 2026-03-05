output "sqs_event_source_mapping_uuids" {
  description = "Map of queue ARN to ESM UUID"
  value       = { for k, v in aws_lambda_event_source_mapping.sqs : k => v.uuid }
}
