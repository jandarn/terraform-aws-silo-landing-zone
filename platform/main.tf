data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = var.s3_bucket_id
    key    = "bootstrap/terraform.tfstate"
    region = var.aws_region
  }
}

# ============= ORGANIZATIONAL UNITS ==============
resource "aws_organizations_organizational_unit" "core_ou" {
  name      = "Core"
  parent_id = data.terraform_remote_state.bootstrap.outputs.org_root_id
}

resource "aws_organizations_organizational_unit" "tenant_ou" {
  name      = "Tenants"
  parent_id = data.terraform_remote_state.bootstrap.outputs.org_root_id
}


# ============ CORE ACCOUNTS ==============
resource "aws_organizations_account" "security_account" {
  name              = "Security"
  email             = local.account_mails.security
  parent_id         = aws_organizations_organizational_unit.core_ou.id
  close_on_deletion = var.close_core_accounts_on_deletion
}

resource "aws_organizations_account" "log_archive_account" {
  name              = "LogArchive"
  email             = local.account_mails.log_archive
  parent_id         = aws_organizations_organizational_unit.core_ou.id
  close_on_deletion = var.close_core_accounts_on_deletion
}

# Delegate administrator of GuardDuty to the Security account
resource "aws_guardduty_organization_admin_account" "security_account" {
  admin_account_id = aws_organizations_account.security_account.id
}

# =========== ACCOUNT PROVISIONING =============
# Provision the core accounts using the AWS provider with assumed roles.

provider "aws" {
  alias  = "security"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.security_account.id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "log_archive"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.log_archive_account.id}:role/OrganizationAccountAccessRole"
  }
}

# ============= RESOURCE PROVISIONING ==============
# As resources need to be provisioned inside the created accounts, we need to assume the OrganizationAccountAccessRole in each account.
# However, this role is assumed requires an AWS provider block, which Terraform reads always before create any account.
# Therefore, we won't be able to assume the role in the account we just created, as it doesn't exist yet.
# To solve this, we will divide the apply operation in two steps: 1) Create the accounts and 2) Assume the role in each account and provision resources. (This is done using the -target option in the apply command)



# ============= S3 BUCKET FOR CLOUDTRAIL LOGS (LOG-ARCHIVE) ==============
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "cloudtrail_logs_bucket" {
  bucket        = "cloudtrail-logs-${random_string.bucket_suffix.result}"
  provider      = aws.log_archive
  force_destroy = var.force_destroy_log_bucket
  lifecycle {
    prevent_destroy = false 
  }
}

# --- bucket properties ---
# versioning
resource "aws_s3_bucket_versioning" "cloudtrail_logs_bucket_versioning" {
  bucket   = aws_s3_bucket.cloudtrail_logs_bucket.id
  provider = aws.log_archive
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_bucket_encryption" {
  bucket   = aws_s3_bucket.cloudtrail_logs_bucket.id
  provider = aws.log_archive
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.cloudtrail_logs_bucket.id
  provider                = aws.log_archive
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}