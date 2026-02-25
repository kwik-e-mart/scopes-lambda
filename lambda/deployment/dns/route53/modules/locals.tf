locals {
  # Module identifier
  dns_module_name = "dns/route53"

  # API Gateway with custom domain -> A alias record
  # count must be known at plan time, so we use a variable set by dns/route53/setup
  dns_use_api_gateway    = var.dns_use_api_gateway
  dns_api_gateway_target = try(local.api_gateway_target_domain, "")
  dns_api_gateway_zone   = try(local.api_gateway_target_zone_id, "")

  # API Gateway without custom domain -> CNAME to default endpoint (strip https://)
  # count must be known at plan time, so we use a variable set by dns/route53/setup
  dns_use_api_gateway_cname    = var.dns_use_api_gateway_cname
  dns_api_gateway_cname_target = replace(try(local.api_gateway_endpoint, ""), "https://", "")

  # Cross-module outputs
  dns_record_name = var.dns_full_domain
}
