data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Key Vault — application secrets
# Public network access disabled; access only via private endpoint.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.name_suffix}-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku

  # Disable public access — private endpoint only
  public_network_access_enabled = false

  # Use Azure RBAC for data-plane authorization (modern approach over access policies)
  enable_rbac_authorization = true

  soft_delete_retention_days = var.environment == "prod" ? 90 : 7 # Min 7d; 90d for prod compliance
  purge_protection_enabled   = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.tags
}

# audit logs to Log Analytics — off by default, enable in prod
# resource "azurerm_monitor_diagnostic_setting" "keyvault" {
#   name                       = "diag-kv-${local.name_suffix}"
#   target_resource_id         = azurerm_key_vault.main.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
#
#   enabled_log { category = "AuditEvent" }
#   metric { category = "AllMetrics" enabled = false }
# }
