variable "tenant_ou_id" {
  description = "The ID of the tenant organizational unit"
  type        = string
}

variable "tenant_name" {
  description = "The name of the tenant"
  type        = string
}

variable "tenant_email" {
  description = "The email address for the tenant account"
  type        = string
}

variable "close_on_deletion" {
  description = "Set to true to close tenant accounts when removed from state"
  type        = bool
  default     = false
}