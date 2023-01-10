variable cloudfront_domain_name {}
variable cloudfront_hosted_zone_id {}
variable domain {}
variable hosted_zone_id {}

# Create a DNS record for the production domain aliased to the CloudFront distribution
resource "aws_route53_record" "production" {
  name    = var.domain
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
  }
}
