resource "azurerm_public_ip" "vpngw_pip" {
  count = 2
  name  = "${var.vpn_gateway_public_ip_name}-${count.index + 1}"
  # name                = var.vpn_gateway_public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_virtual_network_gateway" "hub_vpngw" {
  name                = var.vpn_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = var.hub_vpn_gateway_active_active
  bgp_enabled   = true
  sku           = var.vpn_gateway_sku

  # First IP Configuration
  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.vpngw_pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }

  # Second IP Configuration
  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.vpngw_pip[1].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }

  bgp_settings {
    asn = var.vpn_gateway_bgp_asn
  }
}

resource "azurerm_public_ip" "onprem_vpngw_pip" {
  count = 2
  name  = "${var.onprem_vpn_gateway_public_ip_name}-${count.index + 1}"
  # name                = var.onprem_vpn_gateway_public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_virtual_network_gateway" "onprem_vpngw" {
  name                = var.onprem_vpn_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = true
  bgp_enabled   = true
  sku           = var.onprem_vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.onprem_vpngw_pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem_gateway_subnet.id
  }

  # Second IP Configuration
  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.onprem_vpngw_pip[1].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem_gateway_subnet.id
  }

  bgp_settings {
    asn = var.onprem_vpn_gateway_bgp_asn
  }
}

resource "azurerm_public_ip" "ars_pip" {
  name                = var.route_server_public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "ars" {
  name                             = var.route_server_name
  sku                              = var.route_server_sku
  location                         = azurerm_resource_group.rg.location
  resource_group_name              = azurerm_resource_group.rg.name
  public_ip_address_id             = azurerm_public_ip.ars_pip.id
  subnet_id                        = azurerm_subnet.routeserver_subnet.id
  branch_to_branch_traffic_enabled = var.route_server_branch_to_branch_traffic_enabled
}
