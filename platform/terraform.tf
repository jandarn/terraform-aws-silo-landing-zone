
terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "my-example-bucket-name"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}