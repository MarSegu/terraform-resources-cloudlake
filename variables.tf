variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Environment setting
variable "environment" {
  description = "The environment in which the resources are being deployed (e.g., dev, prod)."
  default     = "dev"
}

# Tags for resource organization and identification
variable "tags" {
  description = "Tags to assign to the resources for categorization and tracking."
  type        = map(string)
  default = {
    environment = "dev"
    application = "cloudlake"
    terraform   = "true"
  }
}

variable "project_name" {
  type    = string
  default = "cloudlake"
}

# MSK
variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
  default     = "cloudlake-admin-key"
}

#site-to-site
variable "preshared_key_1" {
  description = "key for site-to-site tunnel 1 vpn conf"
  type        = string
  default     = "sample1"
}

variable "preshared_key_2" {
  description = "key for site-to-site tunnel 2 vpn conf"
  type        = string
  default     = "sample2"
}

