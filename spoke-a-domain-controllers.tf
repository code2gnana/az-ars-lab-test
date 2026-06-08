locals {
  # Two dedicated AD DS VM instances in Spoke A with fixed private IPs.
  spoke_a_dc_vm_map = {
    dc1 = {
      vm_name       = "vm-spoke-a-dc-1"
      computer_name = "spokeadc1"
      nic_name      = "nic-spoke-a-dc-1"
      private_ip    = "10.3.0.10"
    }
    dc2 = {
      vm_name       = "vm-spoke-a-dc-2"
      computer_name = "spokeadc2"
      nic_name      = "nic-spoke-a-dc-2"
      private_ip    = "10.3.0.11"
    }
  }
}

resource "random_password" "spoke_a_dc_admin_password" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  special          = true
  override_special = "_%@"
}

resource "azurerm_network_interface" "spoke_a_dc" {
  for_each            = local.spoke_a_dc_vm_map
  name                = each.value.nic_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_servers         = ["10.3.0.10", "10.3.0.11"]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spoke_a_default.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
  }
}

resource "azurerm_windows_virtual_machine" "spoke_a_dc" {
  for_each            = local.spoke_a_dc_vm_map
  name                = each.value.vm_name
  computer_name       = each.value.computer_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.spoke_a_dc_vm_size

  # Reuse existing lab username but keep a dedicated password for DC hosts.
  admin_username = var.spoke_test_vm_admin_username
  admin_password = random_password.spoke_a_dc_admin_password.result

  network_interface_ids = [
    azurerm_network_interface.spoke_a_dc[each.key].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.spoke_a_default
  ]
}
