locals {
  # Build deterministic map: ip config name -> gateway BGP peer IP.
  hub_bgp_by_ipconfig = {
    for p in azurerm_virtual_network_gateway.hub_vpngw.bgp_settings[0].peering_addresses :
    p.ip_configuration_name => p.default_addresses[0]
  }

  onprem_bgp_by_ipconfig = {
    for p in azurerm_virtual_network_gateway.onprem_vpngw.bgp_settings[0].peering_addresses :
    p.ip_configuration_name => p.default_addresses[0]
  }

  # Explicit instance inventory allows one LNG+connection per gateway instance.
  gateway_instances = {
    vnetGatewayConfig1 = {
      index = 0
    }
    vnetGatewayConfig2 = {
      index = 1
    }
  }
}

# Preserve existing instance-1 resources during migration to per-instance model.
moved {
  from = azurerm_local_network_gateway.lng_hub
  to   = azurerm_local_network_gateway.lng_hub_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_local_network_gateway.lng_onprem
  to   = azurerm_local_network_gateway.lng_onprem_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_virtual_network_gateway_connection.hub_to_onprem
  to   = azurerm_virtual_network_gateway_connection.hub_to_onprem_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_virtual_network_gateway_connection.onprem_to_hub
  to   = azurerm_virtual_network_gateway_connection.onprem_to_hub_instance["vnetGatewayConfig1"]
}

resource "azurerm_local_network_gateway" "lng_hub_instance" {
  for_each            = local.gateway_instances
  name                = each.key == "vnetGatewayConfig1" ? var.hub_local_network_gateway_name : "${var.hub_local_network_gateway_name}-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.vpngw_pip[each.value.index].ip_address

  bgp_settings {
    asn = var.vpn_gateway_bgp_asn
    # Optional explicit per-instance override; otherwise use discovered mapping.
    bgp_peering_address = coalesce(
      lookup(var.hub_bgp_peering_address_overrides, each.key, null),
      local.hub_bgp_by_ipconfig[each.key]
    )
  }
}

resource "azurerm_local_network_gateway" "lng_onprem_instance" {
  for_each            = local.gateway_instances
  name                = each.key == "vnetGatewayConfig1" ? var.onprem_local_network_gateway_name : "${var.onprem_local_network_gateway_name}-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.onprem_vpngw_pip[each.value.index].ip_address

  bgp_settings {
    asn = var.onprem_vpn_gateway_bgp_asn
    # Optional explicit per-instance override; otherwise use discovered mapping.
    bgp_peering_address = coalesce(
      lookup(var.onprem_bgp_peering_address_overrides, each.key, null),
      local.onprem_bgp_by_ipconfig[each.key]
    )
  }
}

resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem_instance" {
  for_each                   = local.gateway_instances
  name                       = each.key == "vnetGatewayConfig1" ? var.hub_to_onprem_connection_name : "${var.hub_to_onprem_connection_name}-2"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_onprem_instance[each.key].id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub_instance" {
  for_each                   = local.gateway_instances
  name                       = each.key == "vnetGatewayConfig1" ? var.onprem_to_hub_connection_name : "${var.onprem_to_hub_connection_name}-2"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_hub_instance[each.key].id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}
