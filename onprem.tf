resource "azurerm_virtual_network" "onprem" {
  name                = "onprem-vnet"
  location            = azurerm_resource_group.rg_name[0].location
  resource_group_name = azurerm_resource_group.rg_name[0].name
  address_space       = [local.on_prem_cidr]
}

resource "azurerm_subnet" "onprem_vm" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "onprem-vm-1"
    virtual_network_name    = azurerm_virtual_network.onprem.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.onprem.address_space[0],8,0)]
}

resource "azurerm_subnet" "swan" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "swan"
    virtual_network_name    = azurerm_virtual_network.onprem.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.onprem.address_space[0],8,255)]
}

resource "azurerm_subnet" "swan_lan" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "swan-lan"
    virtual_network_name    = azurerm_virtual_network.onprem.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.onprem.address_space[0],8,254)]
}

resource "azurerm_network_security_group" "nsg_vpn" {
  name                = "vpn-nsg"
  location            = azurerm_resource_group.rg_name[0].location
  resource_group_name = azurerm_resource_group.rg_name[0].name
}

resource "azurerm_network_security_rule" "nsg_vpn_rule" {
  name                        = "Allow-all"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_name[0].name
  network_security_group_name = azurerm_network_security_group.nsg_vpn.name
}

resource "azurerm_subnet_network_security_group_association" "onprem_nsg" {
  subnet_id                 = azurerm_subnet.onprem_vm.id
  network_security_group_id = azurerm_network_security_group.nsg_vpn.id
}

resource "azurerm_subnet_network_security_group_association" "swan_nsg" {
  subnet_id                 = azurerm_subnet.swan.id
  network_security_group_id = azurerm_network_security_group.nsg_vpn.id
}

resource "azurerm_public_ip" "onprem_vm_pip" {
  name                    = "onpremVM-pip"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  allocation_method       = "Static"
  sku                     = "Standard"
}

resource "azurerm_network_interface" "onprem_vm_nic" {
  name                    = "onpremVM-nic"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem_vm.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.onprem_vm.address_prefixes[0], 10)
    public_ip_address_id          = azurerm_public_ip.onprem_vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "onprem_vm" {
  name                    = "onpremVM"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.onprem_vm_nic.id
  ]

   custom_data = filebase64("cloud-init.sh")
  
  disable_password_authentication = true
  admin_ssh_key {
        public_key = file(var.ssh_public_key_file)
        username = var.azure_vm_admin_username
    }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_route_table" "onprem_vm_rt" {
  name                    = "rt-vpnVM"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
}

resource "azurerm_route" "onprem_public_internet" {
  name                    = "Internet"
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  route_table_name        = azurerm_route_table.onprem_vm_rt.name
  address_prefix          = "0.0.0.0/0"
  next_hop_type           = "Internet"
  lifecycle {
    ignore_changes = all
  } 
}

resource "azurerm_route" "rfc1918a" {
  name                    = "RFC1918-A"
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  route_table_name        = azurerm_route_table.onprem_vm_rt.name
  address_prefix          = "10.0.0.0/8"
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.swan_nic_lan.private_ip_address
  lifecycle {
    ignore_changes = all
  } 
}

resource "azurerm_route" "rfc1918b" {
  name                    = "RFC1918-B"
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  route_table_name        = azurerm_route_table.onprem_vm_rt.name
  address_prefix          = "172.16.0.0/12"
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.swan_nic_lan.private_ip_address
  lifecycle {
    ignore_changes = all
  } 
}

resource "azurerm_route" "rfc1918c" {
  name                    = "RFC1918-C"
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  route_table_name        = azurerm_route_table.onprem_vm_rt.name
  address_prefix          = "192.168.0.0/16"
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.swan_nic_lan.private_ip_address
  lifecycle {
    ignore_changes = all
  } 
}

resource "azurerm_route" "rfc6888" {
  name                    = "RFC6888"
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  route_table_name        = azurerm_route_table.onprem_vm_rt.name
  address_prefix          = "100.64.0.0/10"
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.swan_nic_lan.private_ip_address
  lifecycle {
    ignore_changes = all
  } 
}

resource "azurerm_subnet_route_table_association" "onprem_vm_rt" {
  subnet_id               = azurerm_subnet.onprem_vm.id
  route_table_id          = azurerm_route_table.onprem_vm_rt.id
}



# NVA


resource "azurerm_public_ip" "swan" {
  name                    = "strongswan"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  allocation_method       = "Static"
  sku                     = "Standard"
}

resource "azurerm_network_interface" "swan_nic" {
  name                    = "strongswan-nic"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  enable_ip_forwarding     = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swan.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swan.id
  }
}

resource "azurerm_network_interface" "swan_nic_lan" {
  name                    = "strongswan-lan"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  enable_ip_forwarding     = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swan_lan.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "swan_vm" {
  count                   =  var.s2c_routing == "static" ? 1 : 0
  name                    = "swan"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.swan_nic.id,
    azurerm_network_interface.swan_nic_lan.id
  ]
 
   custom_data = base64encode(templatefile("swan.tftpl", {
    preshared_key       = "s2cpsk123"
    remote_ip_1         = azurerm_public_ip.vpn[0].ip_address
    local_public_ip     = azurerm_public_ip.swan.ip_address
    local_private_ip    = azurerm_network_interface.swan_nic.private_ip_address
    vnet_cidr           = azurerm_virtual_network.onprem.address_space[0]
    lan_gw              = cidrhost(azurerm_subnet.swan_lan.address_prefixes[0],1)
    vti1_local          = cidrhost(local.tunnel1_cidr, 2)
    vti1_remote         = cidrhost(local.tunnel1_cidr, 1)
  }))
  
  disable_password_authentication = true
  admin_ssh_key {
        public_key = file(var.ssh_public_key_file)
        username = var.azure_vm_admin_username
    }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}


# BGP VM

resource "azurerm_linux_virtual_machine" "swan_vm_bgp" {
  count                   =  var.s2c_routing == "bgp" ? 1 : 0
  name                    = "swan-bgp"
  location                = azurerm_virtual_network.onprem.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.swan_nic.id,
    azurerm_network_interface.swan_nic_lan.id
  ]
 
   custom_data = base64encode(templatefile("bgpswan.tftpl", {
    preshared_key       = "s2cpsk123"
    spoke_gw            = aviatrix_spoke_gateway.spoke_vpn_bgp[0].public_ip
    spoke_gwha          = aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0].public_ip
    local_public_ip     = azurerm_public_ip.swan.ip_address
    local_private_ip    = azurerm_network_interface.swan_nic.private_ip_address
    vnet_cidr           = azurerm_virtual_network.onprem.address_space[0]
    onprem_vm_cidr      = azurerm_subnet.onprem_vm.address_prefixes[0]
    lan_gw              = cidrhost(azurerm_subnet.swan_lan.address_prefixes[0],1)
    vti2_local          = cidrhost(local.tunnel1_cidr, 2)
    vti2_remote         = cidrhost(local.tunnel1_cidr, 1)
    vti3_local          = cidrhost(local.tunnel2_cidr, 2)
    vti3_remote         = cidrhost(local.tunnel2_cidr, 1)
    bgp_router_id       = azurerm_network_interface.swan_nic.private_ip_address
    local_bgp_asn       = var.s2c_onprem_bgp_asn
    remote_bgp_asn      = var.s2c_avx_bgp_asn
  }))
  
  disable_password_authentication = true
  admin_ssh_key {
        public_key = file(var.ssh_public_key_file)
        username = var.azure_vm_admin_username
    }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}