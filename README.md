# terraform-aws-silo-landing-zone

[![Terraform](https://img.shields.io/badge/terraform-v1.5-blueviolet?logo=terraform)](https://www.terraform.io)
[![AWS Provider](https://img.shields.io/badge/aws%20provider-6.0-orange?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws)

Terraform reference architecture: multi-account AWS landing zone with a tenant account factory for regulated fintech platforms.

## Problem
Regulated fintech platforms must keep each client's data, access paths, and audit trail isolated by design. Shared infrastructure with logical separation is not sufficient for compliance-sensitive workloads, so this architecture uses AWS accounts as hard boundaries and automates tenant provisioning through Terraform to keep onboarding repeatable and governed.

## Architecture
This architecture uses AWS accounts as hard boundaries and applies organization-level governance controls while tenant provisioning remains automated through Terraform.

### AWS account architecture
![Account topology](docs/img/account-topology.svg)

1. **Management Account** deploys and configures the platform with limited high-privilege access.
2. **Organization-wide CloudTrail** logs all API activity to a tamper-evident log-archive account with versioning and deny-delete policy.
3. **Terraform state** lives in the Management Account for simplicity. A separate state-management account would reduce blast radius and allow state access to be granted independently of organization-level permissions; that separation is noted as future work.
4. **SCP guardrails** are attached at the OU level (Core and Tenants), enforcing baseline restrictions across all member accounts.
5. **GuardDuty** aggregates findings in the security account as delegated administrator, preventing compromised tenants from suppressing alerts.
6. **Multi-account architecture** with each client having a dedicated AWS account for maximum isolation—one client cannot access another's workload, billing, or audit trails.

### Terraform provisioning flow
![Terraform topology](docs/img/terraform-topology.svg)

1. **Three separate states** — isolated by blast radius, not by execution cadence. A failed destroy remains contained to one layer instead of destroying the entire organization.
2. **Bootstrap self-referencing state** — bootstrap creates the bucket where its own state lives. First apply uses local backend, then `init -migrate-state`. One-time setup, documented.
3. **Unidirectional remote state** — layers communicate only through `terraform_remote_state` in one direction: platform reads bootstrap, tenants read platform. Never reversed. This contract enables separation.
4. **Two-step apply with assume_role** — provisioning new accounts requires `assume_role`; Terraform resolves providers before the dependency graph. Solution: two-step apply with `-target`. This is the real friction point in the design.

## Design decisions and trade-offs

| Decision | Why | Trade-off |
|----------|-----------|-----------|
| **One AWS account per tenant** | AWS account boundaries provide hard isolation; a bug or misconfiguration cannot cross client boundaries without explicit trust relationships. | Higher operational cost. |
| **Custom Terraform vs. AWS Control Tower** | Keeps all infrastructure in version control with diffable changes and visible reasoning. | Increased maintenance burden and ongoing operational work. |
| **Three separate Terraform states** | Bootstrap is separate because it creates the backend the other layers consume — a startup dependency, not a preference. Platform and tenants are separate to contain blast radius: an operator error while vending tenants cannot reach the organization. | Three configurations to maintain; cross-layer references via `terraform_remote_state` must remain stable. |
| **close_on_deletion defaults to false on accounts** | Prevents accidental account closure from configuration edits; account closure is irreversible after 90 days. | The default offboarding pattern is two-step: remove the tenant from configuration, then close the account manually if needed. The toggle exists, but automatic closure is not the default behavior. |

## Tenant onboarding and offboarding

Tenant provisioning is driven by the tenants layer using Terraform. Accounts are defined in `terraform.tfvars` via the `tenant_accounts` variable. Adding a new tenant entry automatically provisions a new AWS account.

### Onboarding

Define tenants in `terraform.tfvars`:

```hcl
tenant_accounts = {
  tenant1 = {
    name  = "tenant1"
    email = "tenant1@example.com"
  }
}
```

Run `terraform apply` to provision the account.

### Offboarding

The tenant account factory exposes a `close_tenant_accounts_on_deletion` toggle, which defaults to `false`. The default operating posture is a two-step offboarding flow: remove the tenant from Terraform management, then close the account manually if needed.

1. Remove the tenant entry from `tenant_accounts` in `terraform.tfvars` and run `terraform apply` to detach the account from Terraform management.

2. Close the account manually in the AWS Console. Closure is reversible for 90 days; after that it is permanent.

## What's built

| Feature | Status |
|---------|--------|
| **Multi-account AWS organization** — Management, Log Archive, and Security accounts with proper role separation. | ✅ |
| **Organization-wide CloudTrail** — Centralized API logging with tamper-evident storage and deny-delete policies. | ✅ |
| **GuardDuty aggregation** — Security account as delegated administrator for organization-wide threat detection. | ✅ |
| **Three-layer Terraform architecture** — Bootstrap (state backend), platform (core infrastructure), and tenants (tenant provisioning). | ✅ |
| **Account factory automation** — Tenant provisioning through Terraform variables with automated account creation, budget setup, and standard tags. | ✅ |
| **Service Control Policies (SCPs)** — Governance controls enforcing compliance across all member accounts. | ✅ |
| **Tenant isolation** — Dedicated AWS accounts per tenant with no cross-tenant access by default. | ✅ |

## Scope and future work

This is a reference architecture, scoped to the account structure, governance controls and provisioning mechanism. Deliberately out of scope:

- **Event-driven provisioning.** Accounts are vended by an operator running Terraform, not by a signup workflow. See Path to automation.
- **Identity federation.** The tenant account is delivered as a governed, empty foundation; access is resolved externally through federation rather than through a tenant-admin role provisioned in Terraform.
- **Dedicated state-management account.** A separate state-management account would reduce blast radius and allow state access to be granted independently of organization-level permissions; this remains a future hardening step.
- **Security Hub and AWS Config.** GuardDuty covers threat detection; broader posture management and configuration compliance are the next layer.
- **Tenant workload networking.** Accounts are delivered as a governed empty foundation; what runs inside is the client's concern.
- **GuardDuty enrollment for core accounts.** With `auto_enable_organization_members = "ALL"`, the management and log-archive accounts did not enroll automatically during testing; only accounts created after the configuration was applied were covered. Log-archive was enrolled manually to verify the delegated administrator setup works. Explicit `aws_guardduty_member` resources for the core accounts are the fix, deferred to v2.

## Path to automation 

A future automation layer could reduce manual effort, but each approach comes with integration complications to consider:

- **VCS-driven automation:** it could make tenant changes reviewable and auditable through pull requests, but the current account creation flow uses a two-step apply with `-target`, which does not fit a single automated run well.
- **Pipeline CI:** it could provide consistent execution and shorter feedback loops, but organization-level permissions would be needed to create accounts and attach guardrails, so role separation would be essential.
- **Event-driven automation:** it could simplify onboarding for non-technical operators, but moving tenant provisioning outside Terraform creates drift risk unless the live state is still reconciled back to configuration. This route also overlaps with existing managed offerings such as Control Tower Account Factory, which were intentionally not chosen for this reference architecture.

## Deployment

### 1. Bootstrap deployment

Bootstrap must be applied first with local state because the S3 backend cannot be initialized until the bucket exists.

```bash
cd bootstrap
terraform init
terraform apply
```

### 2. Bootstrap state migration

Uncomment and complete the backend block in `bootstrap/terraform.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-bucket-id"
    key    = "bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Then run:

```bash
terraform init -migrate-state
```

### 3. Configure platform backend

Add the remote backend configuration to `platform/terraform.tf` (same pattern as bootstrap), using the same S3 bucket.

### 4. Deploy platform with targeted apply

First, provision the core accounts with the actual resource names defined in the code:

```bash
cd platform
terraform apply \
  -target=aws_organizations_account.security_account \
  -target=aws_organizations_account.log_archive_account
```

### 5. Provision remaining platform infrastructure

Deploy the complete platform:

```bash
terraform apply
```

### 6. Provision tenant accounts

Configure the tenant backend in `tenants/terraform.tf`, populate the `tenant_accounts` variable in `terraform.tfvars`, then apply:

```bash
cd tenants
terraform apply
```
## Teardown

Destroy in reverse order of deployment. Each layer depends on the one below it,
and `bootstrap` holds the remote state the other two read.

1. **Tenants.** `cd tenants && terraform destroy`

2. **Platform.** The CloudTrail log bucket is versioned and is not emptied by a
   plain destroy. `force_destroy` is read from state rather than from the
   current configuration, so the flag has to be applied before it takes effect:

```bash
   cd platform
   terraform apply -var="force_destroy_log_bucket=true"
   terraform destroy -var="force_destroy_log_bucket=true"
```

   Alternatively, empty the bucket manually and run a plain destroy.

3. **Bootstrap.** The state bucket cannot be emptied while it is still serving
   as the backend. Comment out the `backend "s3"` block, migrate the state to
   local, then destroy:

```bash
   cd bootstrap
   # comment out the backend "s3" block in terraform.tf
   terraform init -migrate-state
   terraform destroy
```

Member accounts are not closed automatically by default when `terraform destroy`
removes them from state; the account factory's
`close_tenant_accounts_on_deletion` toggle defaults to `false`. If you want to
close the account, do it manually. Closing an AWS account is a deliberate action
with a 90-day suspension period, and the default posture is manual closure rather
than automated closure.