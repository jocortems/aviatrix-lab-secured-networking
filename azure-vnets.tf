resource "azurerm_resource_group" "rg_name" {
  count = length(keys(var.azure_spoke_vnets)) > 0 ? 1 : 0
  name = var.resource_group_name
  location = local.azure_transit[0]["region"]
}

resource "azurerm_virtual_network" "vnet" {
  for_each            = { for each in local.azure_spoke : each.cidr => each}
  name                = format("vnet-%s", replace(each.value.cidr, "/", "-"))
  location            = each.value.region
  resource_group_name = azurerm_resource_group.rg_name[0].name
  address_space       = [each.value.cidr]
}

resource "azurerm_subnet" "aviatrix_primary_gateway" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "aviatrix-primary-gateway"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,255)]
}

resource "azurerm_subnet" "aviatrix_ha_gateway" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "aviatrix-ha-gateway"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,254)]
}

resource "azurerm_subnet" "public_subnet" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "jumpbox-subnet"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,1)]
}

resource "azurerm_subnet" "private_subnet_1" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "web-servers"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,10)]
}

resource "azurerm_subnet" "private_subnet_2" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "kubernetes"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,11)]
}

resource "azurerm_subnet" "private_subnet_3" {
    for_each                = { for each in local.azure_spoke : each.cidr => each}
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "database-servers"
    virtual_network_name    = azurerm_virtual_network.vnet[each.value.cidr].name
    address_prefixes        = [cidrsubnet(each.value.cidr,8,15)]
}

resource "azurerm_network_security_group" "nsg" {
  for_each            = { for each in local.azure_spoke : each.cidr => each}
  name                = format("%s-nsg",replace(each.value.vnet_name,"/", "-"))
  location            = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
}

resource "azurerm_network_security_rule" "nsg_rule" {
  for_each                    = { for each in local.azure_spoke : each.cidr => each}
  name                        = "Allow-home"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = [var.my_ipaddress, replace(data.http.my_ip.response_body,"\n","")]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.value.cidr].name
}

resource "azurerm_subnet_network_security_group_association" "nsg_public_subnet_attach" {
  for_each                  = { for each in local.azure_spoke : each.cidr => each}
  subnet_id                 = azurerm_subnet.public_subnet[each.value.cidr].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.cidr].id
}

resource "azurerm_public_ip" "public_vm_pip" {
  name                    = format("jumpboxVM-pip")
  location                = local.azure_spoke[0].region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  allocation_method       = "Static"
  sku                     = "Standard"
}

resource "azurerm_network_interface" "public_vm_nic" { 
  name                    = format("jumpboxVM-nic")
  location                = local.azure_spoke[0].region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.public_subnet[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].address_prefixes[0], 50)
    public_ip_address_id          = azurerm_public_ip.public_vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
  name                    = format("jumpboxVM")
  location                = local.azure_spoke[0].region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.public_vm_nic.id
  ]

  tags = {
    environment = "bastion"
    avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].spoke_gw_name
  }

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

resource "azurerm_route_table" "public_spoke_rt" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("rt-jumpboxVM-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  lifecycle {
    ignore_changes = [route]
  } 

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "Internet"
  }
}


resource "azurerm_subnet_route_table_association" "public_subnet_rt" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  subnet_id               = azurerm_subnet.public_subnet[each.value.cidr].id
  route_table_id          = azurerm_route_table.public_spoke_rt[each.value.cidr].id
}



##Private Subnet VMs

resource "azurerm_network_interface" "private_vm1_nic" {  
  for_each                = { for each in local.azure_spoke : each.cidr => each }
  name                    = format("privateVM1-nic-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet_1[each.value.cidr].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.private_subnet_1[each.value.cidr].address_prefixes[0], 11)
  }
}

resource "azurerm_linux_virtual_machine" "private_vm_1" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("az-prod1-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.private_vm1_nic[each.value.cidr].id
  ]

  tags = {
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[each.value.cidr].spoke_gw_name
  }

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


resource "azurerm_network_interface" "private_vm12_nic" {  
  for_each                = { for each in local.azure_spoke : each.cidr => each }
  name                    = format("privateVM12-nic-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet_1[each.value.cidr].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.private_subnet_1[each.value.cidr].address_prefixes[0], 21)
  }
}

resource "azurerm_linux_virtual_machine" "private_vm_12" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("az-dev1-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.private_vm12_nic[each.value.cidr].id
  ]

  tags = {
    environment = "dev"
    avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[each.value.cidr].spoke_gw_name
  }

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


resource "azurerm_route_table" "private_spoke_rt_1" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("rt-PrivateVM1-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  lifecycle {
    ignore_changes = [route]
  }

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "None"
  }
}

resource "azurerm_subnet_route_table_association" "private_subnet_rt_1" {
  for_each       = { for each in local.azure_spoke : each.cidr => each }  
  subnet_id      = azurerm_subnet.private_subnet_1[each.value.cidr].id
  route_table_id = azurerm_route_table.private_spoke_rt_1[each.value.cidr].id
}


resource "azurerm_route_table" "private_spoke_rt_2" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("rt-PrivateVM2-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  lifecycle {
    ignore_changes = [route]
  } 

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "None"
  }
}

resource "azurerm_subnet_route_table_association" "private_subnet_rt_2" {
  for_each       = { for each in local.azure_spoke : each.cidr => each }  
  subnet_id      = azurerm_subnet.private_subnet_2[each.value.cidr].id
  route_table_id = azurerm_route_table.private_spoke_rt_2[each.value.cidr].id
}





#### Private VMs Subnet 3 ####


resource "azurerm_network_interface" "private_vm21_nic" {  
  for_each                = { for each in local.azure_spoke : each.cidr => each }
  name                    = format("privateVM21-nic-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet_3[each.value.cidr].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.private_subnet_3[each.value.cidr].address_prefixes[0], 11)
  }
}

resource "azurerm_linux_virtual_machine" "private_vm_21" {  
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("az-prod2-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.private_vm21_nic[each.value.cidr].id
  ]

  tags = {
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[each.value.cidr].spoke_gw_name
  }

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


resource "azurerm_network_interface" "private_vm22_nic" {  
  for_each                = { for each in local.azure_spoke : each.cidr => each }
  name                    = format("privateVM22-nic-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet_3[each.value.cidr].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.private_subnet_3[each.value.cidr].address_prefixes[0], 21)
  }
}

resource "azurerm_linux_virtual_machine" "private_vm_22" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("az-dev2-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  size                    = var.azure_vmSKU
  admin_username          = var.azure_vm_admin_username
  network_interface_ids   = [
    azurerm_network_interface.private_vm22_nic[each.value.cidr].id
  ]

  tags = {
    environment = "dev"
    avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[each.value.cidr].spoke_gw_name
  }

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


resource "azurerm_route_table" "private_spoke_rt_3" {
  for_each                = { for each in local.azure_spoke : each.cidr => each }  
  name                    = format("rt-PrivateVM22-%s", replace(each.value.cidr,"/","-"))
  location                = each.value.region
  resource_group_name     = azurerm_resource_group.rg_name[0].name

  lifecycle {
    ignore_changes = [route]
  }

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "None"
  }
}

resource "azurerm_subnet_route_table_association" "private_subnet_rt_3" {
  for_each       = { for each in local.azure_spoke : each.cidr => each }  
  subnet_id      = azurerm_subnet.private_subnet_3[each.value.cidr].id
  route_table_id = azurerm_route_table.private_spoke_rt_3[each.value.cidr].id
}