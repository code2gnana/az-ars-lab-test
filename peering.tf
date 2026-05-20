resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                         = "peer-hub-to-spoke-a"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_a.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.hub_to_spoke_a_allow_gateway_transit

  depends_on = [azurerm_virtual_network_gateway.hub_vpngw]
}

resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                         = "peer-spoke-a-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.spoke_a_to_hub_use_remote_gateways

  depends_on = [azurerm_virtual_network_gateway.hub_vpngw]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_b" {
  name                         = "peer-hub-to-spoke-b"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_b.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.hub_to_spoke_b_allow_gateway_transit
}

resource "azurerm_virtual_network_peering" "spoke_b_to_hub" {
  name                         = "peer-spoke-b-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.spoke_b_to_hub_use_remote_gateways

  depends_on = [azurerm_virtual_network_gateway.hub_vpngw]
}
