
variable "tenant_accounts" {
  description = "List of tenant AWS accounts"
  type = map(object({
    name  = string
    email = string
  }))
  # empty by default to avoid unwanted account creation during initial setup
  default = {}
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_id" {
  description = "The S3 bucket ID for storing Terraform state"
  type        = string
}

variable "close_tenant_accounts_on_deletion" {
  description = "Set to true to close tenant accounts when removed from Terraform state"
  type        = bool
  default     = false
}