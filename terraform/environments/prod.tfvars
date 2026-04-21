# ---------------------------------------------------------------------------
# Prod environment — non-sensitive variables
# ---------------------------------------------------------------------------

environment = "prod"
location    = "westeurope"
project     = "usecase"

# Networking
vnet_address_space            = ["10.0.0.0/24"]
subnet_container_apps_cidr    = "10.0.0.0/27"
subnet_private_endpoints_cidr = "10.0.0.32/27"

# Hub peering — replace with actual hub VNet details
# hub_vnet_id is injected from GitHub Actions secret TF_VAR_HUB_VNET_ID

# Container App — higher resources for production
container_cpu    = 0.5
container_memory = "1Gi"
app_min_replicas = 1  # Always-on in prod
app_max_replicas = 5

# Storage
storage_account_tier     = "Standard"
storage_replication_type = "ZRS" # Zone-redundant for prod

# Key Vault
key_vault_sku = "standard"

tags = {
  cost_center = "engineering"
  owner       = "platform-team"
}
