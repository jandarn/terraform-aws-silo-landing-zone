
terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "tf-state-o-lnperltmr5-t0cj7u"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}