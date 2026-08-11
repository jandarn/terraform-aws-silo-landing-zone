# terraform-aws-silo-landing-zone

[![Terraform](https://img.shields.io/badge/terraform-v1.5-blueviolet?logo=terraform)](https://www.terraform.io)
[![AWS Provider](https://img.shields.io/badge/aws%20provider-6.0-orange?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws)

Terraform reference architecture: multi-account AWS landing zone with a tenant account factory for regulated fintech platforms.

## Architecture
Regulated fintech platforms require strong data isolation across clients. This architecture uses AWS accounts as hard boundaries and automates tenant provisioning through Terraform, eliminating manual account creation while maintaining governance controls.

### AWS account architecture
![Account topology](docs/img/account-topology.svg)

1. **Management Account** deploys and configures the platform with limited high-privilege access. *(AWS IAM, Access Control)*
2. **Organization-wide CloudTrail** logs all API activity to a tamper-proof log-archive account with versioning and deny-delete policy. *(Compliance, Audit Logging, Security)*
3. **Terraform state** resides in a dedicated operations account, separate from management, enabling independent state access without organization-level permissions. *(Infrastructure-as-Code, DevOps, State Management)*
4. **GuardDuty** aggregates findings in the security account as delegated administrator, preventing compromised tenants from suppressing alerts. *(Threat Detection, Security Operations)*
5. **Multi-account architecture** with each client having a dedicated AWS account for maximum isolation—one client cannot access another's workload, billing, or audit trails. *(Data Isolation, Governance, Compliance)*

### Terraform provisioning flow
![Terraform topology](docs/img/terraform-topology.svg)

1. **Three separate states** — isolated by blast radius, not by execution cadence. A failed destroy remains contained to one layer instead of destroying the entire organization. *(State Management, Infrastructure Safety)*
2. **Bootstrap self-referencing state** — bootstrap creates the bucket where its own state lives. First apply uses local backend, then `init -migrate-state`. One-time setup, documented. *(Infrastructure-as-Code, Automation)*
3. **Unidirectional remote state** — layers communicate only through `terraform_remote_state` in one direction: platform reads bootstrap, tenants read platform. Never reversed. This contract enables separation. *(Dependency Management, Governance)*
4. **Two-step apply with assume_role** — provisioning new accounts requires `assume_role`; Terraform resolves providers before the dependency graph. Solution: two-step apply with `-target`. This is the real friction point in the design. *(Multi-Account Architecture, DevOps)*

## Design decisions and trade-offs

| Decision | Why | Trade-off |
|----------|-----------|-----------|
| **One AWS account per tenant** | AWS account boundaries provide hard isolation; a bug or misconfiguration cannot cross client boundaries without explicit trust relationships. | Higher operational cost. |
| **Custom Terraform vs. AWS Control Tower** | Keeps all infrastructure in version control with diffable changes and visible reasoning. | Increased maintenance burden and ongoing operational work. |
| **Three separate Terraform states** | Isolates blast radius by layer—Bootstrap (one-time), Platform (stable), Factory (per-tenant). Prevents cascading failures. | Three configurations to maintain; cross-layer references via `terraform_remote_state` must remain stable. |
| **close_on_deletion = false on accounts** | Prevents accidental account closure from configuration edits; account closure is irreversible after 90 days. | Offboarding requires two manual steps: remove from config, then close account separately. |

## Tenant onboarding and offboarding

Tenant provisioning is driven by the Factory layer using Terraform. Accounts are defined in `terraform.tfvars` via the `tenant_accounts` variable. Adding a new tenant entry automatically provisions a new AWS account.

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

Offboarding is a two-step manual process to prevent accidental account closure:

1. Remove the tenant entry from `tenant_accounts` in `terraform.tfvars`:

```hcl
tenant_accounts = {}
```

2. Run `terraform apply` to remove the account from configuration (account closure only occurs if `close_tenant_accounts_on_deletion` is `true`).

3. If `close_tenant_accounts_on_deletion` is `false`, manually close the account in the AWS Console. *(Note: Account closure is irreversible after 90 days.)*

## In scope work (Aug, 2026)

| Feature | Status |
|---------|--------|
| **Multi-account AWS organization** — Management, Operations, Log Archive, and Security accounts with proper role separation. | ✅ |
| **Organization-wide CloudTrail** — Centralized API logging with tamper-proof storage and deny-delete policies. | ✅ |
| **GuardDuty aggregation** — Security account as delegated administrator for organization-wide threat detection. | ✅ |
| **Three-layer Terraform architecture** — Bootstrap (state backend), Platform (core infrastructure), and Factory (tenant provisioning). | ✅ |
| **Account factory automation** — Tenant provisioning through Terraform variables with automated account creation and IAM setup. | ✅ |
| **Service Control Policies (SCPs)** — Governance controls enforcing compliance across the organization. | ✅ |
| **Tenant isolation** — Dedicated AWS accounts per tenant with no cross-tenant access by default. | ✅ |

## Scope and future work

This is a reference architecture, scoped to the account structure, governance controls and provisioning mechanism. Deliberately out of scope:

- **Event-driven provisioning.** Accounts are vended by an operator running Terraform, not by a signup workflow. See Path to automation.
- **Identity federation.** The tenant-admin role's trust policy is parameterised; in production this would be backed by IAM Identity Center or an external IdP.
- **Security Hub and AWS Config.** GuardDuty covers threat detection; broader posture management and configuration compliance are the next layer.
- **Tenant workload networking.** Accounts are delivered as a governed empty foundation; what runs inside is the client's concern.

## Path to automation 

1. VCS-driven (HCP Terraform or Atlantis)

The tenant map lives in git; a PR triggers the plan, a merge triggers the apply. Approval is code review.

> Main risk: the two-step apply with -target doesn't fit a single automated execution. Either split the factory into vending/baseline layers or accept that the first run fails. Automation forces you to solve the provider problem first.

2. Pipeline CI (GitHub Actions with OIDC)

Same trigger, but you control the runner and credential chain. OIDC avoids long-lived keys.

> Main risk: the pipeline role needs organization-level permissions—create accounts, attach SCPs. A highly privileged identity living in CI: compromising the pipeline compromises the organization. Mitigation: one role per layer, and the tenant pipeline cannot touch platform. This is where your three-state separation starts paying off.

3. Event-driven (portal or API → EventBridge → workflow)

A commercial signup provisions the account without anyone editing HCL.

> Main risk: Terraform stops being the source of truth for the tenant list unless automation writes back to the map. Drift appears between what exists and what's declared. To be clear: this already exists and it's called Control Tower Account Factory / Service Catalog. Naming it gives you credibility; pretending it doesn't exist takes it away.

## Deployment (PENDING)
Prerequisites: AWS account, Terraform >= 1., credentials with organization-level permissions

1. bootstrap  — organization, Core OU, state backend
2. platform   — core accounts, org-wide CloudTrail, GuardDuty, SCPs
3. tenants    — account factory

Each layer reads the previous one through remote state.