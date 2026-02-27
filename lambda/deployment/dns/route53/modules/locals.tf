locals {
  # Module identifier
  dns_module_name = "dns/route53"

  # API Gateway with custom domain -> A alias record
  # api_gateway_* locals are provided by networking/api_gateway/modules/locals.tf when
  # composed, or by dns/route53/stubs_no_api_gateway/api_gateway_stubs.tf when not composed.
  dns_use_api_gateway    = var.dns_use_api_gateway
  dns_api_gateway_target = local.api_gateway_target_domain
  dns_api_gateway_zone   = local.api_gateway_target_zone_id

  # API Gateway without custom domain -> CNAME to default endpoint (strip https://)
  dns_use_api_gateway_cname    = var.dns_use_api_gateway_cname
  dns_api_gateway_cname_target = replace(local.api_gateway_endpoint, "https://", "")

  # ALB -> A alias record
  # alb_* locals are provided by networking/alb/modules/locals.tf when composed,
  # or by dns/route53/stubs_no_alb/alb_stubs.tf when not composed.
  dns_alb_dns_name = local.alb_dns_name
  dns_alb_zone_id  = local.alb_zone_id

  # Cross-module outputs
  dns_record_name = var.dns_full_domain
}
