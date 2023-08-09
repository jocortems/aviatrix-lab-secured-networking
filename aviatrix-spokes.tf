resource "aviatrix_spoke_gateway" "azure"{
  for_each                          = { for each in local.azure_spoke : each.cidr => each }
  cloud_type                        = 8
  account_name                      = var.azure_account
  gw_name                           = format("azure-%s", replace(each.value.vnet_name,"/","-"))
  vpc_id                            = format("%s:%s:%s", azurerm_virtual_network.vnet[each.value.cidr].name, azurerm_virtual_network.vnet[each.value.cidr].resource_group_name, azurerm_virtual_network.vnet[each.value.cidr].guid)
  vpc_reg                           = each.value.region
  gw_size                           = var.azure_spoke_gw_sku
  subnet                            = azurerm_subnet.aviatrix_primary_gateway[each.value.cidr].address_prefixes[0]
  zone                              = "az-2"
  manage_ha_gateway                 = false
  single_ip_snat                    = true
  tags ={
    private-rt-1 = basename(azurerm_subnet_route_table_association.private_subnet_rt_1[each.value.cidr].route_table_id),
    private-rt-2 = basename(azurerm_subnet_route_table_association.private_subnet_rt_2[each.value.cidr].route_table_id)
  }
}

resource "aviatrix_spoke_ha_gateway" "azure"{
  for_each                          = { for each in local.azure_spoke : each.cidr => each }
  primary_gw_name                   = aviatrix_spoke_gateway.azure[each.value.cidr].gw_name
  subnet                            = azurerm_subnet.aviatrix_ha_gateway[each.value.cidr].address_prefixes[0]
  zone                              = "az-3"
  gw_size                           = var.azure_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "azure_westus2" {
  for_each                = { 
    for each in local.azure_spoke : each.cidr => each
    }

   depends_on = [
    azurerm_subnet_route_table_association.private_subnet_rt_1,
    azurerm_subnet_route_table_association.private_subnet_rt_2,
    azurerm_subnet_route_table_association.public_subnet_rt,
    aviatrix_spoke_ha_gateway.azure
  ]
  spoke_gw_name   = aviatrix_spoke_gateway.azure[each.value.cidr].gw_name
  transit_gw_name = module.azure-transit[each.value.region].transit_gateway.gw_name
  route_tables = [
    "${azurerm_route_table.public_spoke_rt[each.value.cidr].name}:${azurerm_route_table.public_spoke_rt[each.value.cidr].resource_group_name}",
    "${azurerm_route_table.private_spoke_rt_1[each.value.cidr].name}:${azurerm_route_table.private_spoke_rt_1[each.value.cidr].resource_group_name}",
    "${azurerm_route_table.private_spoke_rt_2[each.value.cidr].name}:${azurerm_route_table.private_spoke_rt_2[each.value.cidr].resource_group_name}"
   ]
}

resource "aviatrix_spoke_gateway" "gcp"{
  for_each                          = { for each in local.gcp_dns_target_networks : each.cidr => each }
  cloud_type                        = 4
  account_name                      = var.gcp_account
  gw_name                           = format("gcp-%s", replace(each.value.vnet_name,"/","-"))
  vpc_id                            = format("%s~-~%s", google_compute_network.gcp_vpc[each.value.cidr].name, data.google_project.current.project_id)
  vpc_reg                           = format("%s-a", each.value.region)
  gw_size                           = var.gcp_spoke_gw_sku
  subnet                            = google_compute_subnetwork.aviatrix_primary_gw[each.value.cidr].ip_cidr_range
  manage_ha_gateway                 = false
  enable_global_vpc                 = false
  single_ip_snat                    = true
}

resource "aviatrix_spoke_ha_gateway" "gcp"{
  for_each                          = { for each in local.gcp_dns_target_networks : each.cidr => each }
  primary_gw_name                   = aviatrix_spoke_gateway.gcp[each.value.cidr].gw_name
  subnet                            = google_compute_subnetwork.aviatrix_ha_gw[each.value.cidr].ip_cidr_range
  zone                              = format("%s-b", each.value.region)
  gw_size                           = var.gcp_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "gcp_uswest1" {
  depends_on = [ aviatrix_spoke_ha_gateway.gcp ]
  for_each                = { 
    for each in local.gcp_dns_target_networks : each.cidr => each
    }
  spoke_gw_name   = aviatrix_spoke_gateway.gcp[each.value.cidr].gw_name
  transit_gw_name = module.gcp-transit[each.value.region].transit_gateway.gw_name
}

#We create a single Spoke in GCP which will advertise the CIDR range for GCP DNS forwarder:

resource "aviatrix_spoke_gateway" "gcp-dns"{  
  cloud_type                        = 4
  account_name                      = var.gcp_account
  gw_name                           = "gcp-dns-spoke"
  vpc_id                            = format("%s~-~%s", google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].name, data.google_project.current.project_id)
  vpc_reg                           = format("%s-a", local.gcp_spoke[0].region)
  gw_size                           = var.gcp_spoke_gw_sku
  subnet                            = google_compute_subnetwork.aviatrix_primary_gw[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].ip_cidr_range
  manage_ha_gateway                 = false
  enable_global_vpc                 = false
  single_ip_snat                    = true
  included_advertised_spoke_routes = format("35.199.192.0/19,%s", var.gcp_spoke_vnets[local.gcp_spoke[0].region][0])
}

resource "aviatrix_spoke_ha_gateway" "gcp-dns"{
  primary_gw_name                   = aviatrix_spoke_gateway.gcp-dns.gw_name
  subnet                            = google_compute_subnetwork.aviatrix_ha_gw[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].ip_cidr_range
  zone                              = format("%s-b", local.gcp_spoke[0].region)
  gw_size                           = var.gcp_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "gcp_dns_att" {
  depends_on = [ aviatrix_spoke_ha_gateway.gcp-dns ]
  spoke_gw_name   = aviatrix_spoke_gateway.gcp-dns.gw_name
  transit_gw_name = module.gcp-transit[local.gcp_spoke[0].region].transit_gateway.gw_name
}


resource "aviatrix_spoke_gateway" "aws"{
  for_each                          = { for each in local.aws_spoke : each.cidr => each }
  cloud_type                        = 1
  account_name                      = var.aws_account
  gw_name                           = format("aws-%s", replace(each.value.vnet_name,"/","-"))
  vpc_id                            = aws_vpc.aws_vpc[each.value.cidr].id
  vpc_reg                           = each.value.region
  gw_size                           = var.aws_spoke_gw_sku
  subnet                            = aws_subnet.aviatrix_primary_gw[each.value.cidr].cidr_block
  manage_ha_gateway                 = false
  single_ip_snat                    = true
  tags ={
    private-rt-1 = aws_route_table_association.private_subnet_1_rt_association[each.value.cidr].route_table_id,
    private-rt-2 = aws_route_table_association.private_subnet_2_rt_association[each.value.cidr].route_table_id
  }
}

resource "aviatrix_spoke_ha_gateway" "aws"{
  for_each                          = { for each in local.aws_spoke : each.cidr => each }
  primary_gw_name                   = aviatrix_spoke_gateway.aws[each.value.cidr].gw_name
  subnet                            = aws_subnet.aviatrix_ha_gw[each.value.cidr].cidr_block
  gw_size                           = var.aws_spoke_gw_sku
}

resource "aviatrix_spoke_transit_attachment" "aws_uswest2" {
  for_each                = { 
    for each in local.aws_spoke : each.cidr => each
    }

   depends_on = [
    aws_route_table_association.private_subnet_1_rt_association,
    aws_route_table_association.private_subnet_2_rt_association,
    aviatrix_spoke_ha_gateway.aws
  ]
  spoke_gw_name   = aviatrix_spoke_gateway.aws[each.value.cidr].gw_name
  transit_gw_name = module.aws-transit[each.value.region].transit_gateway.gw_name
  route_tables = [
    aws_route_table.aws_private_route_table_1[each.value.cidr].id,
    aws_route_table.aws_private_route_table_2[each.value.cidr].id
   ]
}