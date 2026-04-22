# Senior Cloud Engineer — Use Case

![Validate](https://github.com/geokef91/senior-cloud-engineer-use-case/actions/workflows/validate.yml/badge.svg)
![Deploy](https://github.com/geokef91/senior-cloud-engineer-use-case/actions/workflows/terraform.yml/badge.svg)

Private Azure deployment of a FastAPI application using Terraform and GitHub Actions.

## Architecture Overview

```
On-Premises (VPN)
       │
  [Hub VNet] ──── VNet Peering ────▶ [vnet-usecase-private-01  10.0.0.0/24]
                                              │
                              ┌───────────────┴───────────────┐
                              │                               │
                    snet-container-apps              snet-pe (private endpoints)
                      10.0.0.0/27                      10.0.0.32/27
                              │                               │
                   [Container Apps Env]          ┌────────────┴────────────┐
                    (internal ingress)            │                         │
                   [FastAPI Container]     [PE: Storage Blob]       [PE: Key Vault]
                   [User-Assigned MI]             │                         │
                                        [Storage Account]           [Key Vault]
                                        (public access OFF)         (public access OFF)
```

## Resources Provisioned

| Resource | Purpose |
|---|---|
| Resource Group | Container for all resources |
| VNet + Subnets | Private network (10.0.0.0/24) |
| NSGs | Traffic control per subnet |
| VNet Peering | Connectivity to hub / on-prem via VPN |
| Container Apps Environment | Managed container runtime (internal only) |
| Container App | FastAPI application |
| Storage Account | Media file exchange (private endpoint only) |
| Key Vault | Application secrets (private endpoint only) |
| User-Assigned Managed Identity | Passwordless auth for app → Azure services |
| Log Analytics Workspace | Container Apps observability |
| Private Endpoints | Storage blob + Key Vault |

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml       # GitOps CI/CD pipeline
└── terraform/
    ├── providers.tf             # Terraform + AzureRM provider config
    ├── variables.tf             # All input variables
    ├── locals.tf                # Computed local values
    ├── networking.tf            # VNet, subnets, NSGs, VNet peering
    ├── container_app.tf         # Container Apps environment + app + Log Analytics
    ├── storage.tf               # Storage account + blob container
    ├── keyvault.tf              # Key Vault
    ├── private_endpoints.tf     # Private endpoints for Storage + Key Vault
    ├── rbac.tf                  # Managed identity + role assignments
    ├── outputs.tf               # Stack outputs
    └── environments/
        ├── dev.tfvars           # Dev environment values
        └── prod.tfvars          # Prod environment values
```

## Terraform State

State is stored remotely in **Azure Blob Storage** with native state locking via blob lease.

The backend uses partial configuration — sensitive values are injected at CI runtime:

```hcl
backend "azurerm" {}
```

```bash
terraform init \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=<state_storage_account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev/terraform.tfstate"
```

State files are **never committed** to this repository (see `.gitignore`).

## Variables Strategy

| Variable type | Where stored |
|---|---|
| Non-sensitive (region, sizing, tags) | `environments/<env>.tfvars` — committed to repo |
| Sensitive (hub VNet ID, container image, subscription ID) | GitHub Actions Secrets → injected as `-var` flags |
| Azure credentials | GitHub Actions OIDC federated identity — no stored secrets |

## GitHub Actions Secrets Required

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | App registration client ID (OIDC) |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `TF_STATE_RESOURCE_GROUP` | Resource group holding Terraform state storage |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name for Terraform state |
| `TF_VAR_HUB_VNET_ID` | Resource ID of the hub VNet |
| `TF_VAR_CONTAINER_IMAGE` | Full container image reference |

## CI/CD Flow (GitOps)

```
Feature branch ──▶ Pull Request ──▶ terraform validate + plan (posted as PR comment)
                                             │
                                    Review & approve PR
                                             │
                          Merge to main ──▶ terraform apply
                                        (with GitHub Environment approval gate for prod)
```

> **Note on CI status:** The `Validate` job passes clean. The `Apply` job fails at Azure Login because this demo repository has no Azure credentials configured — the pipeline code is correct and would succeed with the secrets listed below wired up.

## Local Usage

```bash
cd terraform

terraform init \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=<state_sa>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev/terraform.tfstate"

terraform plan -var-file="environments/dev.tfvars" \
  -var="hub_vnet_id=<hub_vnet_resource_id>" \
  -var="container_image=<registry>/<image>:<tag>"

terraform apply -var-file="environments/dev.tfvars" \
  -var="hub_vnet_id=<hub_vnet_resource_id>" \
  -var="container_image=<registry>/<image>:<tag>"
```

## Application Deployment (out of scope, but how it would work)

This repository covers infrastructure provisioning only. Application deployment would live in a **separate pipeline**, keeping infra and app lifecycles decoupled — infra changes are infrequent and carry higher risk; app deploys happen on every release.

### Pipeline structure

```
Pull Request
  └── docker build
  └── push to ACR  (dev tag, e.g. myacr.azurecr.io/fastapi-app:pr-42)

Merge to main
  └── docker build
  └── push to ACR  (versioned tag, e.g. myacr.azurecr.io/fastapi-app:1.4.2)
  └── az containerapp update --image <new-tag>   # zero-downtime revision swap
```

### Prerequisites

- Azure Container Registry (ACR) — provisioned in the hub or alongside this infrastructure
- The Container App's Managed Identity needs `AcrPull` on the ACR to pull images without credentials
- `TF_VAR_CONTAINER_IMAGE` secret updated to the new image tag on each release (or overridden directly in the deploy step)

### Zero-downtime deploys

Container Apps uses a **revision model** — a new revision is created for each image update. With `revision_mode = "Multiple"` (as configured), multiple revisions coexist and the `traffic_weight` block controls the split. A new deploy creates a new revision alongside the old one; traffic only shifts when the new revision is healthy. Rolling back is a single command:

```bash
az containerapp revision activate --name ca-api-usecase-prod \
  --resource-group rg-usecase-prod \
  --revision <previous-revision-name>
```

The default `traffic_weight { latest_revision = true, percentage = 100 }` sends all traffic to the latest revision. Canary or blue/green can be introduced by splitting that percentage without any infrastructure change.

## Observability

A **Log Analytics Workspace** is provisioned and wired to the Container Apps Environment. Container stdout/stderr and platform metrics (replica count, CPU, memory, request latency) flow there automatically.

For a production setup the following would be added on top:

- **Key Vault diagnostic settings** — audit logs (who accessed/modified which secret) sent to Log Analytics. Commented out in `keyvault.tf`, ready to enable.
- **Storage Account metrics** — transaction errors and availability routed to Log Analytics.
- **Azure Monitor alert rules** — suggested baselines:
  - HTTP 5xx rate > threshold → PagerDuty / email
  - Replica count at `app_max_replicas` for > 5 min → scale ceiling hit, investigate
  - Key Vault `ServiceApiResult` failures → potential auth issue
- **Container App revision health** — Container Apps exposes `/healthz` style probes; configuring `liveness_probe` and `readiness_probe` in the container spec ensures traffic only reaches healthy revisions.

## Key Design Decisions

These are deliberate choices worth explaining during a review or interview.

### 1. `revision_mode = "Multiple"` on the Container App
Single mode is simpler but causes a brief traffic gap during deploys — the old revision is killed before the new one is ready. Multiple mode keeps both revisions alive simultaneously and only shifts traffic once the new revision passes health checks. This gives true zero-downtime deploys and a fast rollback path (reactivate the old revision) at no extra cost.

### 2. Environment-aware soft delete retention (Key Vault)
```hcl
soft_delete_retention_days = var.environment == "prod" ? 90 : 7
```
The minimum is 7 days, sufficient for dev. For prod, 90 days is the recommended baseline for compliance and gives a wide recovery window if a secret is accidentally purged. Dev keeps 7 to allow faster cleanup cycles.

### 3. Environment-aware Log Analytics retention
```hcl
retention_in_days = var.environment == "prod" ? 90 : 30
```
30 days is enough for dev debugging. Prod retention is raised to 90 days to satisfy common audit and incident investigation requirements. Log Analytics charges per GB ingested — keeping dev at 30 days avoids unnecessary cost.

### 4. Blob versioning + soft delete on Storage Account
```hcl
blob_properties {
  versioning_enabled = true
  delete_retention_policy { days = 7 }
}
```
The media container holds uploaded files. Without versioning, an accidental overwrite is permanent. With versioning enabled, every write creates a new version and the previous version is retained for 7 days. This matches the same recovery posture as the Terraform state backend.

### 5. All variables in `variables.tf`
The `cicd_principal_id` variable was originally defined in `rbac.tf` alongside the resource that uses it. Terraform allows this, but it breaks the convention that all input surface lives in one file. Moving it to `variables.tf` means anyone onboarding to the codebase finds the complete list of inputs in one place.

### 6. `ignore_changes` on the container image
```hcl
lifecycle {
  ignore_changes = [template[0].container[0].image]
}
```
The container image is updated by the **app deployment pipeline**, not by this Terraform stack. Without `ignore_changes`, every `terraform plan` after an app release shows a diff trying to revert the image back to whatever is in tfvars. This creates a persistent drift fight between the two pipelines and risks rolling back a live release. Ignoring the image lets Terraform own the infrastructure and the app pipeline own the image tag — clean separation of concerns.

### 7. `depends_on` from Container App to RBAC assignments
```hcl
depends_on = [
  azurerm_role_assignment.app_storage_blob_contributor,
  azurerm_role_assignment.app_keyvault_secrets_user,
]
```
Azure RBAC propagation is eventually consistent and can take up to 2 minutes after a role assignment is created. Without this dependency, Terraform may start the Container App before the Managed Identity has permissions on Storage and Key Vault, causing 403 errors on first boot. `depends_on` makes Terraform wait for the assignments to exist before the app resource is created.

### 8. `CanNotDelete` management lock on prod resource group
```hcl
resource "azurerm_management_lock" "rg" {
  count      = var.environment == "prod" ? 1 : 0
  lock_level = "CanNotDelete"
}
```
A `CanNotDelete` lock on the resource group means `terraform destroy`, a portal click, or a runaway script cannot remove the production stack without first explicitly removing the lock. Applied to prod only (`count = var.environment == "prod" ? 1 : 0`) so dev remains easy to tear down.

### 9. Health probes tied to `revision_mode = "Multiple"`
```hcl
liveness_probe  { transport = "HTTP", path = "/health", port = 8000 }
readiness_probe { transport = "HTTP", path = "/health", port = 8000 }
```
`revision_mode = "Multiple"` keeps the old revision alive until the new one is ready — but "ready" is only meaningful if the platform can actually verify health. Without probes, Container Apps uses a simple timer, which means a bad deploy could start receiving traffic before the app finishes initialising or before it has loaded secrets from Key Vault. The readiness probe blocks traffic; the liveness probe triggers a restart if the app locks up.
