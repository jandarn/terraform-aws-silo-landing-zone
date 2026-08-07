output "tenant_account_id" {
  description = "ID of the created tenant AWS account"
  value       = aws_organizations_account.tenant_accounts.id
}
