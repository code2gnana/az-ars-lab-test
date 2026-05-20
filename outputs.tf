output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.rg.name
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "spoke_a_vnet_id" {
  description = "Spoke A VNet resource ID."
  value       = azurerm_virtual_network.spoke_a.id
}

output "spoke_b_vnet_id" {
  description = "Spoke B VNet resource ID."
  value       = azurerm_virtual_network.spoke_b.id
}

output "vpn_gateway_id" {
  description = "Hub VPN gateway resource ID."
  value       = azurerm_virtual_network_gateway.hub_vpngw.id
}

output "route_server_id" {
  description = "Azure Route Server resource ID."
  value       = azurerm_route_server.ars.id
}
