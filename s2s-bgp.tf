resource "azurerm_local_network_gateway" "lng_hub" {
  name                = var.hub_local_network_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.vpngw_pip[0].ip_address

  bgp_settings {
    asn                 = var.vpn_gateway_bgp_asn
    bgp_peering_address = azurerm_virtual_network_gateway.hub_vpngw.bgp_settings[0].peering_addresses[0].default_addresses[0]
  }
}

resource "azurerm_local_network_gateway" "lng_onprem" {
  name                = var.onprem_local_network_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.onprem_vpngw_pip[0].ip_address

  bgp_settings {
    asn                 = var.onprem_vpn_gateway_bgp_asn
    bgp_peering_address = var.onprem_bgp_peering_address_override != null ? var.onprem_bgp_peering_address_override : azurerm_virtual_network_gateway.onprem_vpngw.bgp_settings[0].peering_addresses[0].default_addresses[0]
  }
}

resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem" {
  name                       = var.hub_to_onprem_connection_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_onprem.id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub" {
  name                       = var.onprem_to_hub_connection_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_hub.id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}
