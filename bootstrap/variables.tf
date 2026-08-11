
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "force_destroy_state_bucket" {
  description = "Set to true to delete all objects when destroying the bootstrap state bucket"
  type        = bool
  default     = false
}