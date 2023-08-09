
module "azure-transit" {
  for_each                      = { for each in local.azure_transit : each.region => each }
  name                          = format("azure-%s", replace(lower(each.value.region), " ", "-"))
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.0"
  account                       = var.azure_account
  cloud                         = "azure"
  region                        = each.value.region
  cidr                          = each.value.cidr
  instance_size                 = each.value.gw_size
  enable_transit_firenet        = each.value.firenet
  insane_mode                   = each.value.hpe
  az1                           = "az-1"
  az2                           = "az-1"
  local_as_number               = each.value.bgp_asn
  resource_group                = azurerm_resource_group.rg_name[0].name
  enable_segmentation           = true
  enable_bgp_over_lan           = each.value.bgpol
  bgp_lan_interfaces_count      = each.value.bgpol_int
}

module "gcp-transit" {
  for_each                      = { for each in local.gcp_transit : each.region => each }
  name                          = format("gcp-%s", each.value.region)
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.0"
  account                       = var.gcp_account
  cloud                         = "gcp"
  region                        = each.value.region
  cidr                          = each.value.cidr
  instance_size                 = each.value.gw_size
  enable_transit_firenet        = each.value.firenet
  lan_cidr                      = each.value.lan_cidr
  insane_mode                   = each.value.hpe
  az1                           = "a"
  az2                           = "b"
  local_as_number               = each.value.bgp_asn
  enable_segmentation           = true
  enable_bgp_over_lan           = each.value.bgpol
  bgp_lan_interfaces            = each.value.bgpol_int
  ha_bgp_lan_interfaces         = each.value.ha_bgpol_int
}

module "aws-transit" {
  for_each                      = { for each in local.aws_transit : each.region => each }
  name                          = format("aws-%s", each.value.region)
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.0"
  account                       = var.aws_account
  cloud                         = "aws"
  region                        = each.value.region
  cidr                          = each.value.cidr
  instance_size                 = each.value.gw_size
  enable_transit_firenet        = each.value.firenet
  insane_mode                   = each.value.hpe
  az1                           = "a"
  az2                           = "b"
  local_as_number               = each.value.bgp_asn
  enable_segmentation           = true
}

module "mc-transit-peering" {
  source  = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version = "1.0.8"
  transit_gateways = concat(local.azure_transit_list, local.aws_transit_list, local.gcp_transit_list)
}

/*
resource "aviatrix_transit_gateway_peering" "azure_aws" {
  count                                       = length(local.azure_aws_transit_pairs)
  transit_gateway_name1                       = module.azure-transit[local.azure_aws_transit_pairs[count.index].az.region].transit_gateway.gw_name
  transit_gateway_name2                       = module.aws-transit[local.azure_aws_transit_pairs[count.index].aws.region].transit_gateway.gw_name
  enable_insane_mode_encryption_over_internet = true
  tunnel_count                                = 8
}

resource "aviatrix_transit_gateway_peering" "aws_gcp" {
  count                                       = length(local.aws_gcp_transit_pairs)
  transit_gateway_name1                       = module.aws-transit[local.aws_gcp_transit_pairs[count.index].aws.region].transit_gateway.gw_name
  transit_gateway_name2                       = module.gcp-transit[local.aws_gcp_transit_pairs[count.index].gcp.region].transit_gateway.gw_name
  enable_insane_mode_encryption_over_internet = true
  tunnel_count                                = 8
}


resource "aviatrix_transit_gateway_peering" "gcp_azure" {
  count                                       = length(local.azure_gcp_transit_pairs)
  transit_gateway_name1                       = module.azure-transit[local.azure_gcp_transit_pairs[count.index].az.region].transit_gateway.gw_name
  transit_gateway_name2                       = module.gcp-transit[local.azure_gcp_transit_pairs[count.index].gcp.region].transit_gateway.gw_name
  enable_insane_mode_encryption_over_internet = true
  tunnel_count                                = 8
}*/