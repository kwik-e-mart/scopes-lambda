variable "dns_hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "dns_domain" {
  description = "Base domain name"
  type        = string
}

variable "dns_subdomain" {
  description = "Subdomain prefix"
  type        = string
}

variable "dns_full_domain" {
  description = "Full domain name (subdomain.domain)"
  type        = string
}

variable "dns_resource_tags_json" {
  description = "Tags for DNS resources"
  type        = map(string)
  default     = {}
}

variable "dns_alb_host_header" {
  description = "ALB DNS name for CNAME record; empty to skip ALB DNS record"
  type        = string
  default     = ""
}

variable "dns_use_api_gateway_cname" {
  description = "Whether to create a CNAME record to the API Gateway default endpoint (no custom domain)"
  type        = bool
  default     = false
}
