# Stub locals for when the ALB module is NOT composed.
# Provides empty values so Route53 locals.tf can reference these
# without Terraform throwing "undeclared local" parse-time errors.
locals {
  alb_dns_name = ""
  alb_zone_id  = ""
}
