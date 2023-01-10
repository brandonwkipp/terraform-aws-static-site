variable "zone_name" {}

resource "aws_route53_zone" "production" {
  force_destroy = false
  name          = var.zone_name
}

output "hosted_zone_id" {
  value = aws_route53_zone.production.zone_id
}
