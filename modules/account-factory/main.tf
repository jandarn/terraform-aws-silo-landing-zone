
# Cycle 1: Create a new AWS account for each tenant in the list
resource "aws_organizations_account" "tenant_accounts" {
  name              = var.tenant_name
  email             = var.tenant_email
  parent_id         = var.tenant_ou_id
  close_on_deletion = var.close_on_deletion
}

# Create budget from the management account and scope it to this linked tenant account.
resource "aws_budgets_budget" "tenant_budget" {
  name         = "${var.tenant_name}-budget"
  budget_type  = "COST"
  limit_amount = "1000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [aws_organizations_account.tenant_accounts.id]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.tenant_email]
  }
}