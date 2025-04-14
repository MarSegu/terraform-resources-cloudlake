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