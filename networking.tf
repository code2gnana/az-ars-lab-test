resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.hub_address_space
}

resource "azurerm_subnet" "hub_default" {
  name                 = "Subnet-Default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.hub_default_subnet_prefixes
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.gateway_subnet_prefixes
}

resource "azurerm_subnet" "routeserver_subnet" {
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.route_server_subnet_prefixes
}

resource "azurerm_virtual_network" "spoke_a" {
  name                = var.spoke_a_vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.spoke_a_address_space
}

resource "azurerm_subnet" "spoke_a_default" {
  name                 = "Subnet-Default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = var.spoke_a_default_subnet_prefixes
}

resource "azurerm_virtual_network" "spoke_b" {
  name                = var.spoke_b_vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.spoke_b_address_space
}

resource "azurerm_subnet" "spoke_b_default" {
  name                 = "Subnet-Default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = var.spoke_b_default_subnet_prefixes
}
