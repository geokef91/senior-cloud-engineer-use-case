# ---------------------------------------------------------------------------
# Dev environment — non-sensitive variables
# Sensitive values (hub_vnet_id, container_image) are passed via
# GitHub Actions secrets and injected as -var flags at plan/apply time.
# ---------------------------------------------------------------------------

environment = "dev"
location    = "westeurope"
project     = "usecase"

# Networking
vnet_address_space            = ["10.0.0.0/24"]
subnet_container_apps_cidr    = "10.0.0.0/27"
subnet_private_endpoints_cidr = "10.0.0.32/27"

# Hub peering — replace with actual hub VNet details
# hub_vnet_id is injected from GitHub Actions secret TF_VAR_HUB_VNET_ID

# Container App
container_cpu    = 0.25
container_memory = "0.5Gi"
app_min_replicas = 0
app_max_replicas = 2

# Storage
storage_account_tier     = "Standard"
storage_replication_type = "LRS"

# Key Vault
key_vault_sku = "standard"

tags = {
  cost_center = "engineering"
  owner       = "platform-team"
}
