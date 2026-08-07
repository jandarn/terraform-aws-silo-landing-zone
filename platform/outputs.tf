
# output the tenant OU ID for use in the tenant module
output "tenant_ou_id" {
  value = aws_organizations_organizational_unit.tenant_ou.id
  type  = string
} 