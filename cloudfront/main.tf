variable aliases {}
variable bucket_name {}
variable certificate_arn {}
variable certificate_validation {}
variable website_endpoint {}

# Create a Cloudfront distribution for the S3 bucket
resource "aws_cloudfront_distribution" "production" {
  aliases             = var.aliases
  default_root_object = "index.html"
  enabled             = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false
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
    domain_name = var.website_endpoint
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
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
  }

  depends_on = [var.certificate_validation]
}

output "domain_name" {
  value = aws_cloudfront_distribution.production.domain_name
}

output "hosted_zone_id" {
  value = aws_cloudfront_distribution.production.hosted_zone_id
}
