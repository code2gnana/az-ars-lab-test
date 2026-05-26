resource "azurerm_route_table" "spoke_a_transit" {
  name                = "rt-spoke-a-transit"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name                   = "to-spoke-b-via-nva"
    address_prefix         = var.spoke_b_address_space[0]
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.nva_private_ip_address
  }
}

resource "azurerm_route_table" "spoke_b_transit" {
  name                = "rt-spoke-b-transit"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name                   = "to-spoke-a-via-nva"
    address_prefix         = var.spoke_a_address_space[0]
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.nva_private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke_a_default" {
  subnet_id      = azurerm_subnet.spoke_a_default.id
  route_table_id = azurerm_route_table.spoke_a_transit.id
}

resource "azurerm_subnet_route_table_association" "spoke_b_default" {
  subnet_id      = azurerm_subnet.spoke_b_default.id
  route_table_id = azurerm_route_table.spoke_b_transit.id
}
