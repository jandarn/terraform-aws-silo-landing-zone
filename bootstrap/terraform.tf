terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#terraform {
#  backend "s3" {
#    bucket = "your-example-bucket-name"
#    key    = "bootstrap/terraform.tfstate"
#    region = "us-east-2"
#  }
#}