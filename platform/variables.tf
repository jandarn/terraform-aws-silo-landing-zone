variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_id" {
  description = "The S3 bucket ID for storing Terraform state"
  type        = string
}

variable "security_account_mail" {
  description = "The email address for the security account"
  type        = string
}

variable "log_archive_account_mail" {
  description = "The email address for the log archive account"
  type        = string
}

variable "force_destroy_log_bucket" {
  description = "Set to true to delete all objects when destroying the CloudTrail logs bucket"
  type        = bool
  default     = false
}

variable "close_core_accounts_on_deletion" {
  description = "Set to true to close core accounts when removed from Terraform state"
  type        = bool
  default     = false
}