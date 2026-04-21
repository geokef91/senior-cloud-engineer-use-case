# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Resource Group deletion lock (prod only)
# Prevents accidental terraform destroy or portal deletion in production.
# ---------------------------------------------------------------------------
resource "azurerm_management_lock" "rg" {
  count      = var.environment == "prod" ? 1 : 0
  name       = "lock-rg-${local.name_suffix}"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "Protect production resources from accidental deletion"
}

# ---------------------------------------------------------------------------
# Virtual Network
# The VNet name is fixed per the assignment spec.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-usecase-private-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.vnet_address_space
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

# Container Apps Environment — requires delegation to Microsoft.App/environments
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps-${local.name_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_container_apps_cidr]

  delegation {
    name = "delegation-container-apps"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private Endpoints — no delegation, no private endpoint network policies
resource "azurerm_subnet" "private_endpoints" {
  name                                          = "snet-pe-${local.name_suffix}"
  resource_group_name                           = azurerm_resource_group.main.name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = [var.subnet_private_endpoints_cidr]
  private_endpoint_network_policies             = "Disabled"
}

# ---------------------------------------------------------------------------
# NSG — Container Apps subnet
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "container_apps" {
  name                = "nsg-container-apps-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  # Allow inbound from the company network (via hub peering / VPN)
  security_rule {
    name                       = "allow-inbound-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Required by Azure Load Balancer health probes
  security_rule {
    name                       = "allow-azure-lb"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound internet traffic
  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow outbound to private endpoints subnet (Storage, Key Vault)
  security_rule {
    name                       = "allow-outbound-private-endpoints"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = var.subnet_container_apps_cidr
    destination_address_prefix = var.subnet_private_endpoints_cidr
  }

  # Allow outbound to Azure services (ACR image pull, Azure Monitor)
  security_rule {
    name                       = "allow-outbound-azure-services"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.subnet_container_apps_cidr
    destination_address_prefix = "AzureCloud"
  }
}

resource "azurerm_subnet_network_security_group_association" "container_apps" {
  subnet_id                 = azurerm_subnet.container_apps.id
  network_security_group_id = azurerm_network_security_group.container_apps.id
}

# ---------------------------------------------------------------------------
# NSG — Private Endpoints subnet
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-pe-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  # Allow inbound only from the Container Apps subnet
  security_rule {
    name                       = "allow-inbound-from-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.subnet_container_apps_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# ---------------------------------------------------------------------------
# VNet Peering — Spoke → Hub
# The return peering (Hub → Spoke) must be created in the hub subscription.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.main.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true # Use hub VPN gateway for on-prem connectivity
}
