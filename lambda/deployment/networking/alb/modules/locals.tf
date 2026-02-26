locals {
  # Module identifier
  alb_module_name = "networking/alb"

  # Default tags
  alb_default_tags = merge(var.alb_resource_tags_json, {
    ManagedBy = "terraform"
    Module    = local.alb_module_name
  })

  # Cross-module outputs (consumed by dns layer)
  alb_target_group_arn  = aws_lb_target_group.lambda.arn
  alb_listener_rule_arn = aws_lb_listener_rule.lambda.arn

  # DNS cross-module outputs: ALB DNS name and hosted zone ID for Route53 A alias record
  alb_dns_name = data.aws_lb.main.dns_name
  alb_zone_id  = data.aws_lb.main.zone_id
}
