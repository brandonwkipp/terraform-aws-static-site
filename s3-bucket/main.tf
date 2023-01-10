variable "bucket_name" {}

# Create an S3 bucket configured as a website
# e.g. domain.com
resource "aws_s3_bucket" "production" {
  acl    = "public-read"
  bucket = var.bucket_name

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_s3_bucket_policy" "production" {
  bucket = aws_s3_bucket.production.id

  policy = <<POLICY
{
  "Id": "Policy1380877762691",
  "Statement": [
    {
      "Sid": "Stmt1380877761162",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.bucket_name}/*",
      "Principal": {
        "AWS": [
          "*"
        ]
      }
    }
  ]
}
  POLICY
}

output "website_endpoint" {
  value = aws_s3_bucket.production.website_endpoint
}
