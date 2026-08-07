output "org_root_id" {
  value = aws_organizations_organization.org.roots[0].id
}

output "org_id" {
  value = aws_organizations_organization.org.id
}

output "state_bucket_id" {
  value = aws_s3_bucket.state.id
}