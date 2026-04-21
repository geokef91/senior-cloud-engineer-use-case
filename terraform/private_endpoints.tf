# ---------------------------------------------------------------------------
# Private Endpoints
#
# Central private DNS zones are deployed in the hub and record creation is
# automated (via Azure Policy / Event Grid). No dns_zone_group blocks are
# needed here — the hub automation handles A-record registration on PE creation.
#
# If central DNS automation is NOT available, uncomment the dns_zone_group
# blocks below and the private DNS zone resources at the bottom of this file.
# ---------------------------------------------------------------------------

# Private Endpoint — Storage Account (blob)
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-storage-blob-${local.name_suffix}"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # if hub doesn't auto-register DNS records, wire this up manually:
  # dns_zone_group {
  #   name                 = "dzg-storage-blob"
  #   private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  # }
}

# Private Endpoint — Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-keyvault-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-keyvault-${local.name_suffix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  # same as above — needed if hub DNS is not managing records
  # dns_zone_group {
  #   name                 = "dzg-keyvault"
  #   private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  # }
}

# private DNS zones — only needed if we're managing DNS ourselves (no hub automation)
# would also need to link these to the VNet so resolution works inside the spoke

# resource "azurerm_private_dns_zone" "blob" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = azurerm_resource_group.main.name
#   tags                = local.tags
# }
#
# resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
#   name                  = "link-blob-${local.name_suffix}"
#   resource_group_name   = azurerm_resource_group.main.name
#   private_dns_zone_name = azurerm_private_dns_zone.blob.name
#   virtual_network_id    = azurerm_virtual_network.main.id
#   registration_enabled  = false
#   tags                  = local.tags
# }
#
# resource "azurerm_private_dns_zone" "vault" {
#   name                = "privatelink.vaultcore.azure.net"
#   resource_group_name = azurerm_resource_group.main.name
#   tags                = local.tags
# }
#
# resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
#   name                  = "link-vault-${local.name_suffix}"
#   resource_group_name   = azurerm_resource_group.main.name
#   private_dns_zone_name = azurerm_private_dns_zone.vault.name
#   virtual_network_id    = azurerm_virtual_network.main.id
#   registration_enabled  = false
#   tags                  = local.tags
# }
