resource "aws_organizations_policy" "deny_log_deletion" {
  name        = "DenyLogDeletion"
  description = "Deny deletion of CloudTrail logs"
  content     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "s3:DeleteObject"
      ],
      "Resource": "${aws_s3_bucket.cloudtrail_logs_bucket.arn}/*"
    }
  ]
}
POLICY
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "deny_non_us_regions" {
  name        = "DenyNonUSRegions"
  description = "Deny creation of resources in non-US regions"
  content     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-east-2",
            "us-west-1",
            "us-west-2"
          ]
        }
      }
    }
  ]
}
POLICY
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "deny_leave_organization" {
  name        = "DenyLeaveOrganization"
  description = "Deny leaving the organization"
  content     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "deny_disable_audit" {
  name        = "DenyDisableAudit"
  description = "Deny disabling of audit services"
  content     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "guardduty:StopMonitoringMembers"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
  type        = "SERVICE_CONTROL_POLICY"
}

# Apply all SCPs to both organizational units.
locals {
  scp_target_ous = {
    core    = aws_organizations_organizational_unit.core_ou.id
    tenants = aws_organizations_organizational_unit.tenant_ou.id
  }

  scp_policies = {
    deny_log_deletion       = aws_organizations_policy.deny_log_deletion.id
    deny_non_us_regions     = aws_organizations_policy.deny_non_us_regions.id
    deny_leave_organization = aws_organizations_policy.deny_leave_organization.id
    deny_disable_audit      = aws_organizations_policy.deny_disable_audit.id
  }
}

resource "aws_organizations_policy_attachment" "scp_to_ous" {
  for_each = {
    for pair in setproduct(keys(local.scp_policies), keys(local.scp_target_ous)) :
    "${pair[0]}_${pair[1]}" => {
      policy_id = local.scp_policies[pair[0]]
      target_id = local.scp_target_ous[pair[1]]
    }
  }

  policy_id = each.value.policy_id
  target_id = each.value.target_id
}
