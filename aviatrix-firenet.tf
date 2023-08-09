module "azure_firenet" {
  source    = "terraform-aviatrix-modules/mc-firenet/aviatrix"
  version   = "v1.5.0"
  for_each  = { for each in local.azure_transit : each.region => each if each.firenet == true }

  transit_module  = module.azure-transit[each.value.region]
  firewall_image  = each.value.fw_image
  username        = each.value.fw_username
  password        = each.value.fw_password
  keep_alive_via_lan_interface_enabled = false
}

module "aws_firenet" {
  source    = "terraform-aviatrix-modules/mc-firenet/aviatrix"
  version   = "v1.5.0"
  for_each  = { for each in local.aws_transit : each.region => each if each.firenet == true }

  transit_module = module.aws-transit[each.value.region]
  firewall_image = each.value.fw_image
}


module "gcp_firenet" {
  source    = "terraform-aviatrix-modules/mc-firenet/aviatrix"
  version   = "v1.5.0"
  for_each  = { for each in local.gcp_transit : each.region => each if each.firenet == true }

  transit_module = module.gcp-transit[each.value.region]
  firewall_image = each.value.fw_image
  mgmt_cidr      = each.value.mgmt_cidr
  egress_cidr    = each.value.egress_cidr
}