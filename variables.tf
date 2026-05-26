variable "subscription_id" {
  description = "Azure subscription ID to deploy resources in."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for the lab resources."
  type        = string
  default     = "rg-ars-end-to-end-lab"
}

variable "location" {
  description = "Azure region where all resources are deployed."
  type        = string
  default     = "eastus"
}

variable "onprem_vnet_name" {
  description = "Name of the simulated on-premises virtual network."
  type        = string
  default     = "vnet-onprem"
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network."
  type        = string
  default     = "vnet-hub"
}

variable "spoke_a_vnet_name" {
  description = "Name of Spoke A virtual network."
  type        = string
  default     = "vnet-spoke-a"
}

variable "spoke_b_vnet_name" {
  description = "Name of Spoke B virtual network."
  type        = string
  default     = "vnet-spoke-b"
}

variable "hub_address_space" {
  description = "Address space for the hub virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_a_address_space" {
  description = "Address space for Spoke A virtual network."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "spoke_b_address_space" {
  description = "Address space for Spoke B virtual network."
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "onprem_address_space" {
  description = "Address space for the simulated on-premises virtual network."
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "hub_default_subnet_prefixes" {
  description = "Address prefixes for the hub default subnet."
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "gateway_subnet_prefixes" {
  description = "Address prefixes for the GatewaySubnet (must be named GatewaySubnet)."
  type        = list(string)
  default     = ["10.0.254.0/24"]
}

variable "route_server_subnet_prefixes" {
  description = "Address prefixes for RouteServerSubnet (must be named RouteServerSubnet)."
  type        = list(string)
  default     = ["10.0.253.0/27"]
}

variable "nva_subnet_name" {
  description = "Name of the subnet used for the Linux NVA in the hub."
  type        = string
  default     = "NvaSubnet"
}

variable "nva_subnet_prefixes" {
  description = "Address prefixes for the NVA subnet in the hub."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "onprem_default_subnet_prefixes" {
  description = "Address prefixes for the simulated on-prem default subnet."
  type        = list(string)
  default     = ["192.168.1.0/24"]
}

variable "onprem_gateway_subnet_prefixes" {
  description = "Address prefixes for the simulated on-prem GatewaySubnet."
  type        = list(string)
  default     = ["192.168.254.0/24"]
}

variable "spoke_a_default_subnet_prefixes" {
  description = "Address prefixes for Spoke A default subnet."
  type        = list(string)
  default     = ["10.1.0.0/24"]
}

variable "spoke_b_default_subnet_prefixes" {
  description = "Address prefixes for Spoke B default subnet."
  type        = list(string)
  default     = ["10.2.0.0/24"]
}

variable "vpn_gateway_name" {
  description = "Name of the hub VPN gateway."
  type        = string
  default     = "vpngw-hub"
}

variable "hub_vpn_gateway_active_active" {
  description = "Whether hub VPN gateway runs in active-active mode."
  type        = bool
  default     = true
}

variable "vpn_gateway_sku" {
  description = "SKU for the VPN gateway."
  type        = string
  default     = "VpnGw1AZ"
}

variable "vpn_gateway_bgp_asn" {
  description = "BGP ASN for the hub VPN gateway."
  type        = number
  default     = 65010
}

variable "ars_bgp_asn" {
  description = "BGP ASN for Azure Route Server (Microsoft-managed value is 65515)."
  type        = number
  default     = 65515
}

variable "vpn_gateway_public_ip_name" {
  description = "Public IP name for the VPN gateway."
  type        = string
  default     = "pip-vpngw"
}

variable "onprem_vpn_gateway_name" {
  description = "Name of the simulated on-prem VPN gateway."
  type        = string
  default     = "vpngw-onprem"
}

variable "onprem_vpn_gateway_sku" {
  description = "SKU for the simulated on-prem VPN gateway."
  type        = string
  default     = "VpnGw1AZ"
}

variable "onprem_vpn_gateway_bgp_asn" {
  description = "BGP ASN for the simulated on-prem VPN gateway."
  type        = number
  default     = 65001
}

variable "onprem_vpn_gateway_public_ip_name" {
  description = "Public IP name for the simulated on-prem VPN gateway."
  type        = string
  default     = "pip-vpngw-onprem"
}

variable "route_server_name" {
  description = "Name of the Azure Route Server."
  type        = string
  default     = "ars-hub"
}

variable "route_server_public_ip_name" {
  description = "Public IP name for the Azure Route Server."
  type        = string
  default     = "pip-routeserver"
}

variable "route_server_sku" {
  description = "SKU for Azure Route Server."
  type        = string
  default     = "Standard"
}

variable "route_server_branch_to_branch_traffic_enabled" {
  description = "Controls branch-to-branch traffic on Azure Route Server."
  type        = bool
  default     = false
}

variable "hub_to_onprem_connection_name" {
  description = "Name for the Hub-to-OnPrem gateway connection."
  type        = string
  default     = "conn-hub-to-onprem"
}

variable "onprem_to_hub_connection_name" {
  description = "Name for the OnPrem-to-Hub gateway connection."
  type        = string
  default     = "conn-onprem-to-hub"
}

variable "hub_local_network_gateway_name" {
  description = "Name for the LNG representing the hub in on-prem context."
  type        = string
  default     = "lng-hub-representation"
}

variable "onprem_local_network_gateway_name" {
  description = "Name for the LNG representing on-prem in hub context."
  type        = string
  default     = "lng-onprem-representation"
}

variable "onprem_bgp_peering_address_override" {
  description = "Optional static on-prem BGP peering IP override for LNG creation when gateway peering addresses are not yet populated."
  type        = string
  default     = null
}

variable "vpn_shared_key" {
  description = "Pre-shared key for S2S IPsec tunnel between hub and simulated on-prem."
  type        = string
  sensitive   = true
  default     = "AzureSecretBGPKey123!"
}

variable "hub_to_spoke_a_allow_gateway_transit" {
  description = "Allow gateway transit from hub to Spoke A."
  type        = bool
  default     = true
}

variable "spoke_a_to_hub_use_remote_gateways" {
  description = "Allow Spoke A to use remote gateways in hub."
  type        = bool
  default     = true
}

variable "hub_to_spoke_b_allow_gateway_transit" {
  description = "Allow gateway transit from hub to Spoke B."
  type        = bool
  default     = false
}

variable "spoke_b_to_hub_use_remote_gateways" {
  description = "Allow Spoke B to use remote gateways in hub."
  type        = bool
  default     = false
}

variable "spoke_test_vm_count" {
  description = "Number of Windows test VMs to create in each spoke."
  type        = number
  default     = 1
}

variable "spoke_test_vm_size" {
  description = "Azure VM size for spoke test VMs."
  type        = string
  default     = "Standard_B2s"
}

variable "spoke_test_vm_admin_username" {
  description = "Local administrator username for spoke test VMs."
  type        = string
  default     = "azureuser"
}

variable "nva_nic_name" {
  description = "Network interface name for the Linux NVA."
  type        = string
  default     = "nic-nva-hub"
}

variable "nva_private_ip_address" {
  description = "Static private IP address for the Linux NVA NIC."
  type        = string
  default     = "10.0.1.10"
}

variable "nva_vm_name" {
  description = "Name of the Linux NVA virtual machine."
  type        = string
  default     = "vm-nva-hub"
}

variable "nva_vm_size" {
  description = "Azure VM size for the Linux NVA."
  type        = string
  default     = "Standard_B2s"
}

variable "nva_admin_username" {
  description = "Admin username for the Linux NVA virtual machine."
  type        = string
  default     = "azureadmin"
}

variable "nva_admin_password" {
  description = "Admin password for the Linux NVA virtual machine."
  type        = string
  sensitive   = true
  default     = "AzureRouteLab123!!"
}

variable "nva_bgp_connection_name" {
  description = "Name of the Route Server BGP connection to the NVA."
  type        = string
  default     = "conn-ars-to-nva"
}

variable "nva_bgp_asn" {
  description = "BGP ASN used by the Linux NVA FRR instance."
  type        = number
  default     = 65002
}

variable "nva_advertised_route" {
  description = "Route prefix advertised from the Linux NVA to Azure Route Server."
  type        = string
  default     = "172.16.0.0/24"
}
