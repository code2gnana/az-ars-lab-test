resource "azurerm_network_interface" "nva_nic" {
  name                  = var.nva_nic_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nva_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.nva_private_ip_address
  }
}

resource "azurerm_linux_virtual_machine" "nva_vm" {
  name                            = var.nva_vm_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.nva_vm_size
  admin_username                  = var.nva_admin_username
  admin_password                  = var.nva_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nva_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    sysctl -w net.ipv4.ip_forward=1
    grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y frr

    ip route replace blackhole ${var.nva_advertised_route}

    sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons

    cat <<EOT > /etc/frr/frr.conf
    frr defaults traditional
    log syslog informational
    router bgp ${var.nva_bgp_asn}
     bgp router-id ${var.nva_private_ip_address}
     neighbor ${cidrhost(var.route_server_subnet_prefixes[0], 4)} remote-as ${var.vpn_gateway_bgp_asn}
     neighbor ${cidrhost(var.route_server_subnet_prefixes[0], 4)} ebgp-multihop 2
     neighbor ${cidrhost(var.route_server_subnet_prefixes[0], 5)} remote-as ${var.vpn_gateway_bgp_asn}
     neighbor ${cidrhost(var.route_server_subnet_prefixes[0], 5)} ebgp-multihop 2
     network ${var.nva_advertised_route}
    EOT

    chown frr:frr /etc/frr/frr.conf
    chmod 640 /etc/frr/frr.conf
    systemctl enable frr
    systemctl restart frr
  EOF
  )
}

resource "azurerm_route_server_bgp_connection" "nva_bgp_peering" {
  name            = var.nva_bgp_connection_name
  route_server_id = azurerm_route_server.ars.id
  peer_asn        = var.nva_bgp_asn
  peer_ip         = azurerm_network_interface.nva_nic.private_ip_address

  depends_on = [azurerm_linux_virtual_machine.nva_vm]
}
