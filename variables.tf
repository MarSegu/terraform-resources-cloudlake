variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Environment setting
variable "environment" {
  description = "The environment in which the resources are being deployed (e.g., dev, prod)."
}

# Tags for resource organization and identification
variable "tags" {
  description = "Tags to assign to the resources for categorization and tracking."
  type        = map(string)
}

variable "project_name" {
  type    = string
  default = "cloudlake"
}

# MSK
variable "ec2_msk_key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

#site-to-site
variable "vpn_preshared_key_1" {
  description = "key for site-to-site tunnel 1 vpn conf"
  type        = string
  sensitive   = true
}

variable "vpn_preshared_key_2" {
  description = "key for site-to-site tunnel 2 vpn conf"
  type        = string
  sensitive   = true
}

variable "redshift_db_username" {
  description = "DB username for DB in Redshift cluster"
  type        = string
}

variable "redshift_db_password" {
  description = "DB password for DB in Redshift cluster"
  type        = string
}

