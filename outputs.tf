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
