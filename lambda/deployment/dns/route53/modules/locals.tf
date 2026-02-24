locals {
  # Module identifier
  dns_module_name = "dns/route53"

  # API Gateway with custom domain -> A alias record
  dns_use_api_gateway        = try(local.api_gateway_target_domain, "") != ""
  dns_api_gateway_target     = try(local.api_gateway_target_domain, "")
  dns_api_gateway_zone       = try(local.api_gateway_target_zone_id, "")

  # API Gateway without custom domain -> CNAME to default endpoint (strip https://)
  dns_api_gateway_raw_endpoint  = try(local.api_gateway_endpoint, "")
  dns_use_api_gateway_cname     = !local.dns_use_api_gateway && local.dns_api_gateway_raw_endpoint != ""
  dns_api_gateway_cname_target  = replace(local.dns_api_gateway_raw_endpoint, "https://", "")

  # Cross-module outputs
  dns_record_name = var.dns_full_domain
}
