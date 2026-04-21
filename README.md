# Senior Cloud Engineer — Use Case

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
