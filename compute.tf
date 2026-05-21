locals {
  spoke_test_vm_map = {
    for item in flatten([
      for spoke_name, subnet_id in {
        spoke-a = azurerm_subnet.spoke_a_default.id
        spoke-b = azurerm_subnet.spoke_b_default.id
        } : [
        for idx in range(var.spoke_test_vm_count) : {
          key           = "${spoke_name}-${idx + 1}"
          vm_name       = "vm-${spoke_name}-win22-${idx + 1}"
          computer_name = replace("${spoke_name}vm${idx + 1}", "-", "")
          nic_name      = "nic-${spoke_name}-win22-${idx + 1}"
          subnet_id     = subnet_id
        }
      ]
    ]) : item.key => item
  }
}

resource "azurerm_network_security_group" "spoke_test" {
  name                = "nsg-spokes-test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_icmp_between_spokes" {
  name                         = "allow-icmp-between-spokes"
  priority                     = 100
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Icmp"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefixes      = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  destination_address_prefixes = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  resource_group_name          = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.spoke_test.name
}

resource "azurerm_network_security_rule" "allow_iperf3_tcp_between_spokes" {
  name                         = "allow-iperf3-tcp-between-spokes"
  priority                     = 110
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5201"
  source_address_prefixes      = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  destination_address_prefixes = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  resource_group_name          = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.spoke_test.name
}

resource "azurerm_network_security_rule" "allow_iperf3_udp_between_spokes" {
  name                         = "allow-iperf3-udp-between-spokes"
  priority                     = 120
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Udp"
  source_port_range            = "*"
  destination_port_range       = "5201"
  source_address_prefixes      = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  destination_address_prefixes = [var.spoke_a_address_space[0], var.spoke_b_address_space[0]]
  resource_group_name          = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.spoke_test.name
}

resource "azurerm_subnet_network_security_group_association" "spoke_a_default" {
  subnet_id                 = azurerm_subnet.spoke_a_default.id
  network_security_group_id = azurerm_network_security_group.spoke_test.id
}

resource "azurerm_subnet_network_security_group_association" "spoke_b_default" {
  subnet_id                 = azurerm_subnet.spoke_b_default.id
  network_security_group_id = azurerm_network_security_group.spoke_test.id
}

resource "random_password" "spoke_test_vm_admin_password" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  special          = true
  override_special = "_%@"
}

resource "azurerm_network_interface" "spoke_test" {
  for_each            = local.spoke_test_vm_map
  name                = each.value.nic_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "spoke_test" {
  for_each            = local.spoke_test_vm_map
  name                = each.value.vm_name
  computer_name       = each.value.computer_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.spoke_test_vm_size
  admin_username      = var.spoke_test_vm_admin_username
  admin_password      = random_password.spoke_test_vm_admin_password.result
  network_interface_ids = [
    azurerm_network_interface.spoke_test[each.key].id
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
    azurerm_subnet_network_security_group_association.spoke_a_default,
    azurerm_subnet_network_security_group_association.spoke_b_default
  ]
}

resource "azurerm_virtual_machine_extension" "spoke_test_network_tools" {
  for_each                   = azurerm_windows_virtual_machine.spoke_test
  name                       = "install-network-tools"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"$ProgressPreference='SilentlyContinue'; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) }; choco feature enable -n allowGlobalConfirmation; choco install nmap iperf3 -y\""
  })
}
