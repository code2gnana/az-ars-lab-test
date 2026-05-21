variable "subscription_id" {
  description = "Azure subscription ID to deploy resources in."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for the lab resources."
  type        = string
  default     = "rg-ars-leak-testing"
}

variable "location" {
  description = "Azure region where all resources are deployed."
  type        = string
  default     = "eastus"
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

variable "vpn_gateway_sku" {
  description = "SKU for the VPN gateway."
  type        = string
  default     = "VpnGw1AZ"
}

variable "vpn_gateway_bgp_asn" {
  description = "BGP ASN for the VPN gateway."
  type        = number
  default     = 65515
}

variable "vpn_gateway_public_ip_name" {
  description = "Public IP name for the VPN gateway."
  type        = string
  default     = "pip-vpngw"
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
