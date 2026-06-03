output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.rg.name
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "onprem_vnet_id" {
  description = "Simulated on-prem VNet resource ID."
  value       = azurerm_virtual_network.onprem.id
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

output "onprem_vpn_gateway_id" {
  description = "Simulated on-prem VPN gateway resource ID."
  value       = azurerm_virtual_network_gateway.onprem_vpngw.id
}

output "route_server_id" {
  description = "Azure Route Server resource ID."
  value       = azurerm_route_server.ars.id
}

output "nva_vm_id" {
  description = "Linux NVA virtual machine resource ID."
  value       = azurerm_linux_virtual_machine.nva_vm.id
}

output "nva_private_ip_address" {
  description = "Static private IP used by the Linux NVA."
  value       = azurerm_network_interface.nva_nic.private_ip_address
}

output "nva_bgp_connection_id" {
  description = "Route Server BGP connection resource ID for the Linux NVA."
  value       = azurerm_route_server_bgp_connection.nva_bgp_peering.id
}

output "hub_to_onprem_connection_id" {
  description = "Primary (instance 1) gateway connection from hub to simulated on-prem."
  value       = azurerm_virtual_network_gateway_connection.hub_to_onprem_instance["vnetGatewayConfig1"].id
}

output "onprem_to_hub_connection_id" {
  description = "Primary (instance 1) gateway connection from simulated on-prem to hub."
  value       = azurerm_virtual_network_gateway_connection.onprem_to_hub_instance["vnetGatewayConfig1"].id
}

output "hub_to_onprem_connection_ids" {
  description = "Gateway connection IDs from hub to simulated on-prem by gateway instance."
  value       = { for k, v in azurerm_virtual_network_gateway_connection.hub_to_onprem_instance : k => v.id }
}

output "onprem_to_hub_connection_ids" {
  description = "Gateway connection IDs from simulated on-prem to hub by gateway instance."
  value       = { for k, v in azurerm_virtual_network_gateway_connection.onprem_to_hub_instance : k => v.id }
}

output "spoke_test_vm_names" {
  description = "Names of the Windows Server 2022 test VMs in both spokes."
  value       = [for vm in azurerm_windows_virtual_machine.spoke_test : vm.name]
}

output "spoke_test_vm_private_ips" {
  description = "Private IP addresses for spoke test VM NICs."
  value       = { for k, nic in azurerm_network_interface.spoke_test : k => nic.ip_configuration[0].private_ip_address }
}

output "spoke_test_vm_admin_username" {
  description = "Local administrator username for all spoke test VMs."
  value       = var.spoke_test_vm_admin_username
}

output "spoke_test_vm_admin_password" {
  description = "Generated local administrator password for all spoke test VMs."
  value       = random_password.spoke_test_vm_admin_password.result
  sensitive   = true
}

output "onprem_test_vm_name" {
  description = "Name of the on-prem Windows Server 2022 test VM."
  value       = azurerm_windows_virtual_machine.onprem_test.name
}

output "onprem_test_vm_private_ip" {
  description = "Private IP address of the on-prem test VM NIC."
  value       = azurerm_network_interface.onprem_test.ip_configuration[0].private_ip_address
}

output "onprem_test_vm_admin_username" {
  description = "Local administrator username for the on-prem test VM."
  value       = var.onprem_test_vm_admin_username
}

output "onprem_test_vm_admin_password" {
  description = "Generated local administrator password for the on-prem test VM."
  value       = random_password.onprem_test_vm_admin_password.result
  sensitive   = true
}
