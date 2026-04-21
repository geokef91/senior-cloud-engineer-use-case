output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Resource ID of the spoke VNet"
  value       = azurerm_virtual_network.main.id
}

output "container_app_fqdn" {
  description = "Internal FQDN of the Container App (reachable only within the VNet)"
  value       = azurerm_container_app.api.latest_revision_fqdn
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "managed_identity_client_id" {
  description = "Client ID of the app managed identity"
  value       = azurerm_user_assigned_identity.app.client_id
}
