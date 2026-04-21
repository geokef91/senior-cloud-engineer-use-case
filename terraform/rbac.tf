# ---------------------------------------------------------------------------
# User-Assigned Managed Identity
#
# User-assigned is preferred over system-assigned because:
#   - Explicit lifecycle management (not tied to a single resource)
#   - Role assignments survive resource recreation
#   - Reusable across resources if needed
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-app-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Role Assignments — least privilege
# ---------------------------------------------------------------------------

# Storage: read and write blobs only (not manage the account)
resource "azurerm_role_assignment" "app_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Key Vault: read secrets only (not manage keys or certificates)
resource "azurerm_role_assignment" "app_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# ---------------------------------------------------------------------------
# CI/CD Service Principal — Key Vault Secrets Officer
# Allows the pipeline to write secrets (e.g., connection strings) to Key Vault.
# The principal_id is passed as a variable so no credentials are hardcoded.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "cicd_keyvault_officer" {
  count                = var.cicd_principal_id != "" ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.cicd_principal_id
}

# ACR image pull — add this when ACR is provisioned (hub or spoke)
# scope should be the ACR resource ID, not the whole subscription
# resource "azurerm_role_assignment" "app_acr_pull" {
#   scope                = var.acr_id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_user_assigned_identity.app.principal_id
# }
