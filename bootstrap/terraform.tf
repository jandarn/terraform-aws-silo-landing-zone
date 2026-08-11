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

terraform {
  backend "s3" {
    bucket = "tf-state-o-lnperltmr5-t0cj7u"
    key    = "bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}