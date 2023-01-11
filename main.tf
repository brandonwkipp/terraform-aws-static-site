variable aws_access_key {}
variable aws_secret_key {}

# Cloudfront websites need to be in us-east-1
provider "aws" {
  access_key = var.aws_access_key
  alias      = "us-east-1"
  region     = "us-east-1"
  secret_key = var.aws_secret_key
}

# Create an S3 bucket configured as a website
resource "aws_s3_bucket" "domain" {
  acl    = "public-read"
  bucket = var.bucket_name

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    "Name"        = var.bucket_name
    "Environment" = var.stage
    "ManagedBy"   = "Terraform Cloud"
  }
}

resource "aws_s3_bucket_policy" "domain" {
  bucket = aws_s3_bucket.domain.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1380877761162",
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.domain.arn}/*",
      "Principal": {
        "AWS": "*"
      }
    }
  ]
}
POLICY
}

# Create HTTPS certificate
resource "aws_acm_certificate" "domain" {
  domain_name               = var.bucket_name
  provider                  = aws.us-east-1
  subject_alternative_names = concat(var.subject_alternative_names, keys(var.redirects))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"        = var.bucket_name
    "Environment" = var.stage
    "ManagedBy"   = "Terraform Cloud"
  }
}

# Create a DNS record for the certificate to validate against
resource "aws_route53_record" "domain_dns_validation" {
  for_each = {
    for dvo in aws_acm_certificate.domain.domain_validation_options : dvo.domain_name => {
      hosted_zone_id = can(regex(var.bucket_name, dvo.domain_name)) ? var.hosted_zone_id : var.redirects[dvo.domain_name]
      name           = dvo.resource_record_name
      record         = dvo.resource_record_value
      type           = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.hosted_zone_id
}

# Ensure the certificate is validated correctly
resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = aws_acm_certificate.domain.arn
  depends_on              = [aws_route53_record.domain_dns_validation]
  provider                = aws.us-east-1
  validation_record_fqdns = [for record in aws_route53_record.domain_dns_validation : record.fqdn]
}

# Create a Cloudfront distribution for the S3 bucket
resource "aws_cloudfront_distribution" "domain" {
  aliases             = concat(var.subject_alternative_names, keys(var.redirects), [var.bucket_name])
  default_root_object = "index.html"
  enabled             = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.domain.website_endpoint
    origin_id   = "S3-${var.bucket_name}"

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    "Name"        = var.bucket_name
    "Environment" = var.stage
    "ManagedBy"   = "Terraform Cloud"
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate_validation.domain.certificate_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
  }

  depends_on = [aws_acm_certificate_validation.domain]
}

resource "aws_ssm_parameter" "domain_cloudfront_id" {
  name  = "/cloudfront-distribution/${replace(var.bucket_name, ".", "-")}"
  type  = "String"
  value = aws_cloudfront_distribution.domain.id
}

# Create a DNS record for the domain aliased to the CloudFront distribution
resource "aws_route53_record" "domain_dns" {
  allow_overwrite = false
  name            = var.bucket_name
  type            = "A"
  zone_id         = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.domain.domain_name
    zone_id                = aws_cloudfront_distribution.domain.hosted_zone_id
  }
}

resource "aws_route53_record" "domain_subject_alternate_names" {
  for_each = {
    for domain in concat(var.subject_alternative_names, keys(var.redirects)) : domain => {
      hosted_zone_id = can(regex(var.bucket_name, domain)) ? var.hosted_zone_id : var.redirects[domain]
      name           = domain
    }
  }

  allow_overwrite = false
  name            = each.value.name
  type            = "A"
  zone_id         = each.value.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.domain.domain_name
    zone_id                = aws_cloudfront_distribution.domain.hosted_zone_id
  }
}
