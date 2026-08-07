
# get the organization root id from the bootstrap module
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = var.s3_bucket_id
    key    = "platform/terraform.tfstate"
    region = var.aws_region
  }
}

# call tenant module for each tenant account in the tenant map
module "tenants" {
  source            = "../modules/account-factory"
  for_each          = var.tenant_accounts
  tenant_name       = each.value.name
  tenant_email      = each.value.email
  tenant_ou_id      = data.terraform_remote_state.platform.outputs.tenant_ou_id
  close_on_deletion = var.close_tenant_accounts_on_deletion
}