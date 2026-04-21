# ---------------------------------------------------------------------------
# Storage Account — media file exchange
# Public network access is fully disabled; access only via private endpoint.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                     = "st${replace(local.name_suffix, "-", "")}01"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type

  # Disable all public internet access
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  # Enforce HTTPS and minimum TLS version
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  # Disable shared key access — force Azure AD / managed identity auth only
  shared_access_key_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = local.tags
}

# Blob container for media file exchange
resource "azurerm_storage_container" "media" {
  name                  = "media"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# lifecycle policy — media files are hot on upload, then rarely touched
# tier to cool after 30d, archive at 90d, delete at 1y — adjust to actual usage
# resource "azurerm_storage_management_policy" "main" {
#   storage_account_id = azurerm_storage_account.main.id
#
#   rule {
#     name    = "tier-and-expire-media"
#     enabled = true
#     filters {
#       blob_types   = ["blockBlob"]
#       prefix_match = ["media/"]
#     }
#     actions {
#       base_blob {
#         tier_to_cool_after_days_since_modification_greater_than    = 30
#         tier_to_archive_after_days_since_modification_greater_than = 90
#         delete_after_days_since_modification_greater_than          = 365
#       }
#     }
#   }
# }
