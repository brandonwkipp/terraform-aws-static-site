variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "bucket_name" {
  type = string
}

variable "hosted_zone_id" {
  type      = string
  sensitive = true
}

variable "redirects" {
  type    = map(any)
  default = {}
}

variable "region" {
  type = string
}

variable "subject_alternative_names" {
  type = list(string)
}
