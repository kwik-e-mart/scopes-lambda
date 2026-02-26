# Stub locals for when the API Gateway module is NOT composed.
# Provides empty values so Route53 locals.tf can reference these
# without Terraform throwing "undeclared local" parse-time errors.
locals {
  api_gateway_target_domain  = ""
  api_gateway_target_zone_id = ""
  api_gateway_endpoint       = ""
}
