bucket         = "cloudlake-directory-tf-state"
key            = "cloudlake/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-lock-table"
encrypt        = true