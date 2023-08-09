resource "azurerm_virtual_network" "vpn_vnet" {
  name                = "vpn-vnet"
  location            = local.azure_spoke[0].region
  resource_group_name = azurerm_resource_group.rg_name[0].name
  address_space       = [var.s2c_spoke_cidr]
}

resource "azurerm_subnet" "aviatrix_primary_gateway_vpn" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "aviatrix-primary-gateway"
    virtual_network_name    = azurerm_virtual_network.vpn_vnet.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.vpn_vnet.address_space[0],8,255)]
}

resource "azurerm_subnet" "aviatrix_ha_gateway_vpn" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "aviatrix-ha-gateway"
    virtual_network_name    = azurerm_virtual_network.vpn_vnet.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.vpn_vnet.address_space[0],8,254)]
}

resource "azurerm_subnet" "vpn_subnet" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "vpn-subnet"
    virtual_network_name    = azurerm_virtual_network.vpn_vnet.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.vpn_vnet.address_space[0],8,0)]
}

resource "azurerm_subnet" "vpn_subnetha" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "vpn-subnetha"
    virtual_network_name    = azurerm_virtual_network.vpn_vnet.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.vpn_vnet.address_space[0],8,1)]
}

resource "azurerm_subnet" "private_subnet" {
    resource_group_name     = azurerm_resource_group.rg_name[0].name
    name                    = "private-subnet"
    virtual_network_name    = azurerm_virtual_network.vpn_vnet.name
    address_prefixes        = [cidrsubnet(azurerm_virtual_network.vpn_vnet.address_space[0],8,10)]
}

resource "azurerm_public_ip" "vpn" {
  count                   = lower(var.s2c_routing) == "static" ? 1 : 0
  name                    = "vpngw-vip"
  location                = azurerm_virtual_network.vpn_vnet.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  allocation_method       = "Static"
  sku                     = "Standard"

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_public_ip" "vpn_ha" {
  count                   = lower(var.s2c_routing) == "static" ? 1 : 0
  name                    = "vpngwha-vip"
  location                = azurerm_virtual_network.vpn_vnet.location
  resource_group_name     = azurerm_resource_group.rg_name[0].name
  allocation_method       = "Static"
  sku                     = "Standard"

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_route_table" "vpn_rt" {
  name                    = "vpn-rt"
  location                = azurerm_virtual_network.vpn_vnet.location
  resource_group_name     = azurerm_virtual_network.vpn_vnet.resource_group_name

  lifecycle {
    ignore_changes = [route]
  } 

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "Internet"
  }
}


resource "azurerm_route_table" "private_rt" {
  name                    = "private-rt"
  location                = azurerm_virtual_network.vpn_vnet.location
  resource_group_name     = azurerm_virtual_network.vpn_vnet.resource_group_name

  lifecycle {
    ignore_changes = [route]
  } 

  route {
    name                    = "Internet"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "None"
  }
}

resource "azurerm_subnet_route_table_association" "vpn_rt_assoc" {
  subnet_id               = azurerm_subnet.vpn_subnet.id
  route_table_id          = azurerm_route_table.vpn_rt.id
}

resource "azurerm_subnet_route_table_association" "private_rt_assoc" {
  subnet_id               = azurerm_subnet.private_subnet.id
  route_table_id          = azurerm_route_table.private_rt.id
}

resource "azurerm_subnet_route_table_association" "vpnha_rt_assoc" {
  subnet_id               = azurerm_subnet.vpn_subnetha.id
  route_table_id          = azurerm_route_table.vpn_rt.id
}

resource "aviatrix_gateway" "vpngw" {  
  count      = lower(var.s2c_routing) == "static" ? 1 : 0
  depends_on = [ 
    aviatrix_spoke_transit_attachment.vpn_spoke[0]
   ]
  cloud_type                                = 8
  account_name                              = var.azure_account
  gw_name                                   = "s2c"
  vpc_id                                    = format("%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name)
  vpc_reg                                   = local.azure_spoke[0].region
  gw_size                                   = var.azure_spoke_gw_sku
  subnet                                    = azurerm_subnet.vpn_subnet.address_prefixes[0]
  zone                                      = "az-1"
  peering_ha_subnet                         = azurerm_subnet.vpn_subnetha.address_prefixes[0]
  peering_ha_zone                           = "az-1"
  peering_ha_gw_size                        = var.azure_spoke_gw_sku
  allocate_new_eip                          = false  
  eip                                       = azurerm_public_ip.vpn[0].ip_address
  peering_ha_eip                            = azurerm_public_ip.vpn_ha[0].ip_address
  azure_eip_name_resource_group             = format("%s:%s", azurerm_public_ip.vpn[0].name, azurerm_public_ip.vpn[0].resource_group_name)
  peering_ha_azure_eip_name_resource_group  = format("%s:%s", azurerm_public_ip.vpn_ha[0].name, azurerm_public_ip.vpn_ha[0].resource_group_name)
}

resource "azurerm_network_security_rule" "vpngw_nat_rule" {
  count      = lower(var.s2c_routing) == "static" ? 1 : 0
  depends_on = [ aviatrix_gateway.vpngw[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s", aviatrix_gateway.vpngw[0].gw_name)
}

resource "azurerm_network_security_rule" "vpngwha_nat_rule" {
  count      = lower(var.s2c_routing) == "static" ? 1 : 0
  depends_on = [ aviatrix_gateway.vpngw[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s-hagw", aviatrix_gateway.vpngw[0].gw_name)
}

resource "aviatrix_spoke_gateway" "spoke_vpn"{
  count                             = lower(var.s2c_routing) == "static" ? 1 : 0
  cloud_type                        = 8
  account_name                      = var.azure_account
  gw_name                           = "spoke-vpn"
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name, azurerm_virtual_network.vpn_vnet.guid)
  vpc_reg                           = local.azure_spoke[0].region
  gw_size                           = var.azure_spoke_gw_sku
  subnet                            = azurerm_subnet.aviatrix_primary_gateway_vpn.address_prefixes[0]
  zone                              = "az-1"
  manage_ha_gateway                 = false
  single_ip_snat                    = false
  included_advertised_spoke_routes = "100.64.0.0/10"
  tags = {
    vpn-rt = basename(azurerm_subnet_route_table_association.vpn_rt_assoc.route_table_id),
    private-rt = basename(azurerm_subnet_route_table_association.private_rt_assoc.route_table_id)
  }
}

resource "aviatrix_spoke_ha_gateway" "spoke_vpn_ha"{
  count                             = lower(var.s2c_routing) == "static" ? 1 : 0
  primary_gw_name                   = aviatrix_spoke_gateway.spoke_vpn[0].gw_name
  subnet                            = azurerm_subnet.aviatrix_ha_gateway_vpn.address_prefixes[0]
  zone                              = "az-1"
  gw_size                           = var.azure_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "vpn_spoke" {
   count      = lower(var.s2c_routing) == "static" ? 1 : 0
   depends_on = [
    aviatrix_spoke_ha_gateway.spoke_vpn_ha[0],
    azurerm_subnet_route_table_association.vpn_rt_assoc,
    azurerm_subnet_route_table_association.vpnha_rt_assoc,
    azurerm_subnet_route_table_association.private_rt_assoc
  ]
  spoke_gw_name   = aviatrix_spoke_gateway.spoke_vpn[0].gw_name
  transit_gw_name = module.azure-transit[local.azure_transit[0]["region"]].transit_gateway.gw_name
  route_tables = [
    "${azurerm_route_table.vpn_rt.name}:${azurerm_route_table.vpn_rt.resource_group_name}",
    "${azurerm_route_table.private_rt.name}:${azurerm_route_table.private_rt.resource_group_name}"
  ]
}

resource "azurerm_network_security_rule" "vpnsoke_nat_rule" {
  count                       = lower(var.s2c_routing) == "static" ? 1 : 0
  depends_on = [ aviatrix_spoke_gateway.spoke_vpn[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s", aviatrix_spoke_gateway.spoke_vpn[0].gw_name)
}

resource "azurerm_network_security_rule" "vpnsokeha_nat_rule" {
  count                       = lower(var.s2c_routing) == "static" ? 1 : 0
  depends_on = [ aviatrix_spoke_ha_gateway.spoke_vpn_ha[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s", aviatrix_spoke_ha_gateway.spoke_vpn_ha[0].gw_name)
}


resource "aviatrix_spoke_gateway" "spoke_vpn_bgp"{
  count                             = lower(var.s2c_routing) == "bgp" ? 1 : 0
  cloud_type                        = 8
  account_name                      = var.azure_account
  gw_name                           = "spoke-vpn-bgp"
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name, azurerm_virtual_network.vpn_vnet.guid)
  vpc_reg                           = local.azure_spoke[0].region
  gw_size                           = var.azure_spoke_gw_sku
  subnet                            = azurerm_subnet.aviatrix_primary_gateway_vpn.address_prefixes[0]
  zone                              = "az-1"
  manage_ha_gateway                 = false
  single_ip_snat                    = false
  enable_bgp                        = true
  local_as_number                   = var.s2c_avx_bgp_asn
  enable_preserve_as_path           = false
  included_advertised_spoke_routes = "100.64.0.0/10"
  tags = {
    vpn-rt = basename(azurerm_subnet_route_table_association.vpn_rt_assoc.route_table_id),
    private-rt = basename(azurerm_subnet_route_table_association.private_rt_assoc.route_table_id)
  }
}

resource "aviatrix_spoke_ha_gateway" "spoke_vpn_ha_bgp"{
  count                             = lower(var.s2c_routing) == "bgp" ? 1 : 0
  primary_gw_name                   = aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name
  subnet                            = azurerm_subnet.aviatrix_ha_gateway_vpn.address_prefixes[0]
  zone                              = "az-1"
  gw_size                           = var.azure_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "vpn_spoke_bgp" {
   count      = lower(var.s2c_routing) == "bgp" ? 1 : 0
   depends_on = [
    aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0]
  ]
  spoke_gw_name   = aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name
  transit_gw_name = module.azure-transit[local.azure_transit[0]["region"]].transit_gateway.gw_name
}


resource "azurerm_network_security_rule" "vpnspoke_nat_rule_bgp" {
  count                       = lower(var.s2c_routing) == "bgp" ? 1 : 0
  depends_on = [ aviatrix_spoke_gateway.spoke_vpn_bgp[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s", aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name)
}

resource "azurerm_network_security_rule" "vpnsokeha_nat_rule_bgp" {
  count                       = lower(var.s2c_routing) == "bgp" ? 1 : 0
  depends_on = [ aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0] ]
  name                        = "nat_rule_tf"
  priority                    = 999
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vpn_vnet.resource_group_name
  network_security_group_name = format("av-sg-%s", aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0].gw_name)
}

# Unmaped Connection

resource "aviatrix_site2cloud" "s2c_custom" {
  count                             = lower(var.s2c_nat) == "custom" && lower(var.s2c_routing) == "static" ? 1 : 0
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name, azurerm_virtual_network.vpn_vnet.guid)
  connection_name                   = "s2c-custom-nat"
  connection_type                   = "unmapped"
  remote_gateway_type               = "generic"
  tunnel_type                       = "route"
  primary_cloud_gateway_name        = aviatrix_gateway.vpngw[0].gw_name
  remote_gateway_ip                 = azurerm_public_ip.swan.ip_address
  remote_subnet_cidr                = azurerm_subnet.onprem_vm.address_prefixes[0]
  local_subnet_cidr                 = var.azure_spoke_vnets[local.azure_spoke[0].region][0]
  local_tunnel_ip                   = format("%s/30", cidrhost(local.tunnel1_cidr, 1))
  remote_tunnel_ip                  = format("%s/30", cidrhost(local.tunnel1_cidr, 2))
  ha_enabled                        = true
  enable_single_ip_ha               = true
  backup_gateway_name               = aviatrix_gateway.vpngw[0].peering_ha_gw_name
  custom_algorithms                 = true
  phase_1_authentication            = "SHA-256"
  phase_2_authentication            = "NO-AUTH"
  phase_1_dh_groups                 = "14"
  phase_2_dh_groups                 = "14"
  phase_1_encryption                = "AES-256-CBC"
  phase_2_encryption                = "AES-256-GCM-128"
  pre_shared_key                    = "s2cpsk123"
  enable_ikev2                      = true
  enable_dead_peer_detection        = true
}


resource "aviatrix_gateway_dnat" "to_overlap" {
  count   = lower(var.s2c_nat) == "custom" && lower(var.s2c_routing) == "static" ? 1 : 0
  gw_name = aviatrix_gateway.vpngw[0].gw_name
  dnat_policy {
    dst_cidr = "100.64.10.4/32"
    connection   = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm1_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.10.5/32"
    connection   = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm12_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.1/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.3/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.2/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_ingress.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.1/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.3/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.2/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_ingress.records)[0]
    apply_route_entry = false
  }
}


resource "aviatrix_gateway_dnat" "to_overlap_ha" {
  count   = lower(var.s2c_nat) == "custom" && lower(var.s2c_routing) == "static" ? 1 : 0
  gw_name   = aviatrix_gateway.vpngw[0].peering_ha_gw_name
  dnat_policy {
    dst_cidr = "100.64.10.4/32"
    connection   = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm1_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.10.5/32"
    connection   = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm12_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.1/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.3/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.2/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_ingress.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.1/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.3/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.2/32"
    connection = format("%s@site2cloud", aviatrix_site2cloud.s2c_custom[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_ingress.records)[0]
    apply_route_entry = false
  }
}


resource "aviatrix_gateway_snat" "from_overlap" {
  count   = lower(var.s2c_nat) == "custom" && lower(var.s2c_routing) == "static" ? 1 : 0
  gw_name   = aviatrix_gateway.vpngw[0].gw_name
  snat_mode = "customized_snat"
  snat_policy {
    interface   = "eth0"
    src_cidr    = azurerm_virtual_network.onprem.address_space[0]    
    snat_ips    = "100.127.255.100"
    exclude_rtb = ""
  }
}

resource "aviatrix_gateway_snat" "from_overlap_ha" {
  count   = lower(var.s2c_nat) == "custom" && lower(var.s2c_routing) == "static" ? 1 : 0
  gw_name   = aviatrix_gateway.vpngw[0].peering_ha_gw_name
  snat_mode = "customized_snat"
  snat_policy {
    interface   = "eth0"
    src_cidr    = azurerm_virtual_network.onprem.address_space[0]
    snat_ips    = "100.127.255.100"
    exclude_rtb = ""
  }
}



# Mapped S2C

resource "aviatrix_site2cloud" "s2c_mapped" {
  count                             = lower(var.s2c_nat) == "mapped" && lower(var.s2c_routing) == "static" ? 1 : 0
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name, azurerm_virtual_network.vpn_vnet.guid)
  connection_name                   = "s2c-mapped-nat"
  connection_type                   = "mapped"
  remote_gateway_type               = "generic"
  tunnel_type                       = "route"
  primary_cloud_gateway_name        = aviatrix_gateway.vpngw[0].gw_name
  remote_gateway_ip                 = azurerm_public_ip.swan.ip_address
  custom_mapped                     = true
  remote_source_real_cidrs          = azurerm_virtual_network.onprem.address_space
  remote_source_virtual_cidrs       = ["100.127.0.0/16"]
  remote_destination_real_cidrs     = concat(local.azure_vnet_list, local.aws_vpc_list, local.gcp_vpc_list)
  remote_destination_virtual_cidrs  = concat(["100.64.0.0/16"], slice(local.azure_vnet_list, 1, length(local.azure_vnet_list)), local.aws_vpc_list, local.gcp_vpc_list)
  local_source_real_cidrs           = concat(local.azure_vnet_list, local.aws_vpc_list, local.gcp_vpc_list)
  local_source_virtual_cidrs        = concat(["100.64.0.0/16"], slice(local.azure_vnet_list, 1, length(local.azure_vnet_list)), local.aws_vpc_list, local.gcp_vpc_list)
  local_destination_real_cidrs      = azurerm_virtual_network.onprem.address_space
  local_destination_virtual_cidrs   = ["100.127.0.0/16"]
  local_tunnel_ip                   = format("%s/30", cidrhost(local.tunnel1_cidr, 1))
  remote_tunnel_ip                  = format("%s/30", cidrhost(local.tunnel1_cidr, 2))
  ha_enabled                        = true
  enable_single_ip_ha               = true
  backup_gateway_name               = aviatrix_gateway.vpngw[0].peering_ha_gw_name
  custom_algorithms                 = true
  phase_1_authentication            = "SHA-256"
  phase_2_authentication            = "NO-AUTH"
  phase_1_dh_groups                 = "14"
  phase_2_dh_groups                 = "14"
  phase_1_encryption                = "AES-256-CBC"
  phase_2_encryption                = "AES-256-GCM-128"
  pre_shared_key                    = "s2cpsk123"
  enable_ikev2                      = true
  enable_dead_peer_detection        = true
}

# BGP to spoke

resource "aviatrix_spoke_external_device_conn" "s2c_bgp" {
  count                             = lower(var.s2c_routing) == "bgp" ? 1 : 0
  depends_on = [ 
    aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0]
   ]
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vpn_vnet.name, azurerm_virtual_network.vpn_vnet.resource_group_name, azurerm_virtual_network.vpn_vnet.guid)
  connection_name                   = "s2c-bgp-custom-nat"
  connection_type                   = "bgp"
  gw_name                           = aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name
  tunnel_protocol                   = "IPsec"
  bgp_local_as_num                  = aviatrix_spoke_gateway.spoke_vpn_bgp[0].local_as_number
  bgp_remote_as_num                 = var.s2c_onprem_bgp_asn
  remote_gateway_ip                 = azurerm_public_ip.swan.ip_address
  local_tunnel_cidr                 = format("%s/30,%s/30", cidrhost(local.tunnel1_cidr, 1), cidrhost(local.tunnel2_cidr, 1))
  remote_tunnel_cidr                = format("%s/30,%s/30", cidrhost(local.tunnel1_cidr, 2), cidrhost(local.tunnel2_cidr, 2))
  custom_algorithms                 = true
  phase_1_authentication            = "SHA-256"
  phase_2_authentication            = "NO-AUTH"
  phase_1_dh_groups                 = "14"
  phase_2_dh_groups                 = "14"
  phase_1_encryption                = "AES-256-CBC"
  phase_2_encryption                = "AES-256-GCM-128"
  pre_shared_key                    = "s2cpsk123"
  enable_ikev2                      = true
  manual_bgp_advertised_cidrs       = concat(["100.64.0.0/16"], slice(local.azure_vnet_list, 1, length(local.azure_vnet_list)), local.aws_vpc_list, local.gcp_vpc_list)
}

resource "aviatrix_gateway_dnat" "to_overlap_bgp" {
  depends_on = [ 
    aviatrix_spoke_gateway.spoke_vpn_bgp[0]
  ]
  count   = lower(var.s2c_routing) == "bgp" ? 1 : 0
  gw_name = aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name
  dnat_policy {
    dst_cidr = "100.64.10.4/32"
    connection   = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm1_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.10.5/32"
    connection   = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm12_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.1/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.3/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.2/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_ingress.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.1/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.3/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.2/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_ingress.records)[0]
    apply_route_entry = false
  }
}

resource "aviatrix_gateway_dnat" "to_overlap_ha_bgp" {
  count   = lower(var.s2c_routing) == "bgp" ? 1 : 0
  gw_name   = aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0].gw_name
  dnat_policy {
    dst_cidr = "100.64.10.4/32"
    connection   = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm1_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.10.5/32"
    connection   = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = azurerm_network_interface.private_vm12_nic[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].ip_configuration[0].private_ip_address
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.1/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.3/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.100.2/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.aks_myipapp_ingress.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.1/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.3/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_getcerts_service.records)[0]
    apply_route_entry = false
  }

  dnat_policy {
    dst_cidr = "100.64.110.2/32"
    connection = format("%s@site2cloud", aviatrix_spoke_external_device_conn.s2c_bgp[0].connection_name)
    dnat_ips = tolist(data.azurerm_private_dns_a_record.gke_myipapp_ingress.records)[0]
    apply_route_entry = false
  }
}


resource "aviatrix_gateway_snat" "from_overlap_bgp" {
  depends_on = [ 
    aviatrix_spoke_gateway.spoke_vpn_bgp[0]
  ]
  count   = lower(var.s2c_routing) == "bgp" ? 1 : 0
  gw_name   = aviatrix_spoke_gateway.spoke_vpn_bgp[0].gw_name
  snat_mode = "customized_snat"
  snat_policy {
    connection  = aviatrix_spoke_transit_attachment.vpn_spoke_bgp[0].transit_gw_name
    src_cidr    = azurerm_virtual_network.onprem.address_space[0]    
    snat_ips    = "100.127.255.100"
    exclude_rtb = ""
  }
}

resource "aviatrix_gateway_snat" "from_overlap_ha_bgp" {
  count   = lower(var.s2c_routing) == "bgp" ? 1 : 0
  gw_name   = aviatrix_spoke_ha_gateway.spoke_vpn_ha_bgp[0].gw_name
  snat_mode = "customized_snat"
  snat_policy {
    connection  = aviatrix_spoke_transit_attachment.vpn_spoke_bgp[0].transit_gw_name
    src_cidr    = azurerm_virtual_network.onprem.address_space[0]
    snat_ips    = "100.127.255.101"
    exclude_rtb = ""
  }
}
