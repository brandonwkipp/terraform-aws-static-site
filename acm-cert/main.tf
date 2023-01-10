variable "domain" {}
variable "subject_alternative_names" {}
variable "zones" {}

# Create a HTTPS certificate
resource "aws_acm_certificate" "production" {
  domain_name               = var.domain
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create a DNS record for the production certificate to validate against
resource "aws_route53_record" "production_dns_validation" {
  for_each = {
    for dvo in aws_acm_certificate.production.domain_validation_options : dvo.domain_name => {
      domain = dvo.domain_name
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = lookup(var.zones, each.value.domain)
}

# Ensure the production certificate is validated correctly
resource "aws_acm_certificate_validation" "production" {
  certificate_arn         = aws_acm_certificate.production.arn
  validation_record_fqdns = [for record in aws_route53_record.production_dns_validation : record.fqdn]
}

output "arn" {
  value = aws_acm_certificate.production.arn
}
