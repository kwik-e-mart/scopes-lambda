# DNS Record for API Gateway (alias record)
resource "aws_route53_record" "api_gateway" {
  count = local.dns_use_api_gateway ? 1 : 0

  zone_id = var.dns_hosted_zone_id
  name    = var.dns_full_domain
  type    = "A"

  alias {
    name                   = local.dns_api_gateway_target
    zone_id                = local.dns_api_gateway_zone
    evaluate_target_health = false
  }
}

# DNS CNAME Record for API Gateway without custom domain
resource "aws_route53_record" "api_gateway_cname" {
  count = local.dns_use_api_gateway_cname ? 1 : 0

  zone_id = var.dns_hosted_zone_id
  name    = var.dns_full_domain
  type    = "CNAME"
  ttl     = 300

  records = [local.dns_api_gateway_cname_target]
}

# DNS A alias record for ALB (private/internal scopes)
# Triggered by the ALB module's cross-module local alb_dns_name (non-empty when ALB is composed).
resource "aws_route53_record" "alb" {
  count = local.dns_alb_dns_name != "" ? 1 : 0

  zone_id = var.dns_hosted_zone_id
  name    = var.dns_full_domain
  type    = "A"

  alias {
    name                   = local.dns_alb_dns_name
    zone_id                = local.dns_alb_zone_id
    evaluate_target_health = true
  }
}
