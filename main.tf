# terraform {
#   backend "s3" {
#     bucket         = "cloudlake-directory-tf-state"
#     key            = "cloudlake/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-lock-table"
#     encrypt        = true
#   }

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }
terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}