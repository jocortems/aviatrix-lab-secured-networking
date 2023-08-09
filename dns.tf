
# Azure DNS Configuration

resource "azurerm_private_dns_zone" "cse_org" {
  name                = var.internal_dns_zone
  resource_group_name = azurerm_resource_group.rg_name[0].name
}

resource "azurerm_private_dns_a_record" "azure_prod1" {
  for_each            = { for each in local.azure_spoke : each.cidr => each }
  name                = format("az-prod%s", (tonumber(element(split(".", azurerm_network_interface.private_vm1_nic[each.value.cidr].private_ip_address), 1)) + tonumber(element(split(".", azurerm_network_interface.private_vm1_nic[each.value.cidr].private_ip_address), 2)) + tonumber(element(split(".", azurerm_network_interface.private_vm1_nic[each.value.cidr].private_ip_address), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.private_vm1_nic[each.value.cidr].private_ip_address]
}

resource "azurerm_private_dns_a_record" "azure_prod2" {
  for_each            = { for each in local.azure_spoke : each.cidr => each }
  name                = format("az-prod%s", (tonumber(element(split(".", azurerm_network_interface.private_vm21_nic[each.value.cidr].private_ip_address), 1)) + tonumber(element(split(".", azurerm_network_interface.private_vm21_nic[each.value.cidr].private_ip_address), 2)) + tonumber(element(split(".", azurerm_network_interface.private_vm21_nic[each.value.cidr].private_ip_address), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.private_vm21_nic[each.value.cidr].private_ip_address]
}

resource "azurerm_private_dns_a_record" "azure_dev1" {
  for_each            = { for each in local.azure_spoke : each.cidr => each }
  name                = format("az-dev%s", (tonumber(element(split(".", azurerm_network_interface.private_vm12_nic[each.value.cidr].private_ip_address), 1)) + tonumber(element(split(".", azurerm_network_interface.private_vm12_nic[each.value.cidr].private_ip_address), 2)) + tonumber(element(split(".", azurerm_network_interface.private_vm12_nic[each.value.cidr].private_ip_address), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.private_vm12_nic[each.value.cidr].private_ip_address]
}

resource "azurerm_private_dns_a_record" "azure_dev2" {
  for_each            = { for each in local.azure_spoke : each.cidr => each }
  name                = format("az-dev%s", (tonumber(element(split(".", azurerm_network_interface.private_vm22_nic[each.value.cidr].private_ip_address), 1)) + tonumber(element(split(".", azurerm_network_interface.private_vm22_nic[each.value.cidr].private_ip_address), 2)) + tonumber(element(split(".", azurerm_network_interface.private_vm22_nic[each.value.cidr].private_ip_address), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.private_vm22_nic[each.value.cidr].private_ip_address]
}

# AWS Records

resource "azurerm_private_dns_a_record" "aws_prod1" {
  for_each            = { for each in local.aws_spoke : each.cidr => each }
  name                = format("aws-prod%s", (tonumber(element(split(".", aws_instance.ec2_1[each.value.cidr].private_ip), 1)) + tonumber(element(split(".", aws_instance.ec2_1[each.value.cidr].private_ip), 2)) + tonumber(element(split(".", aws_instance.ec2_1[each.value.cidr].private_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [aws_instance.ec2_1[each.value.cidr].private_ip]
}

resource "azurerm_private_dns_a_record" "aws_prod2" {
  for_each            = { for each in local.aws_spoke : each.cidr => each }
  name                = format("aws-prod%s", (tonumber(element(split(".", aws_instance.ec2_2[each.value.cidr].private_ip), 1)) + tonumber(element(split(".", aws_instance.ec2_2[each.value.cidr].private_ip), 2)) + tonumber(element(split(".", aws_instance.ec2_2[each.value.cidr].private_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [aws_instance.ec2_2[each.value.cidr].private_ip]
}

resource "azurerm_private_dns_a_record" "aws_dev1" {
  for_each            = { for each in local.aws_spoke : each.cidr => each }
  name                = format("aws-dev%s", (tonumber(element(split(".", aws_instance.ec2_12[each.value.cidr].private_ip), 1)) + tonumber(element(split(".", aws_instance.ec2_12[each.value.cidr].private_ip), 2)) + tonumber(element(split(".", aws_instance.ec2_12[each.value.cidr].private_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [aws_instance.ec2_12[each.value.cidr].private_ip]
}

resource "azurerm_private_dns_a_record" "aws_dev2" {
  for_each            = { for each in local.aws_spoke : each.cidr => each }
  name                = format("aws-dev%s", (tonumber(element(split(".", aws_instance.ec2_21[each.value.cidr].private_ip), 1)) + tonumber(element(split(".", aws_instance.ec2_21[each.value.cidr].private_ip), 2)) + tonumber(element(split(".", aws_instance.ec2_21[each.value.cidr].private_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [aws_instance.ec2_21[each.value.cidr].private_ip]
}


# GCP Records

resource "azurerm_private_dns_a_record" "gcp_prod1" {
  for_each            = { for each in local.gcp_dns_target_networks : each.cidr => each }
  name                = format("gcp-prod%s", (tonumber(element(split(".", google_compute_instance.prod_instance[each.value.cidr].network_interface.0.network_ip), 1)) + tonumber(element(split(".", google_compute_instance.prod_instance[each.value.cidr].network_interface.0.network_ip), 2)) + tonumber(element(split(".", google_compute_instance.prod_instance[each.value.cidr].network_interface.0.network_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [google_compute_instance.prod_instance[each.value.cidr].network_interface.0.network_ip]
}

resource "azurerm_private_dns_a_record" "gcp_prod2" {
  for_each            = { for each in local.gcp_dns_target_networks : each.cidr => each }
  name                = format("gcp-prod%s", (tonumber(element(split(".", google_compute_instance.prod_instance2[each.value.cidr].network_interface.0.network_ip), 1)) + tonumber(element(split(".", google_compute_instance.prod_instance2[each.value.cidr].network_interface.0.network_ip), 2)) + tonumber(element(split(".", google_compute_instance.prod_instance2[each.value.cidr].network_interface.0.network_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [google_compute_instance.prod_instance2[each.value.cidr].network_interface.0.network_ip]
}

resource "azurerm_private_dns_a_record" "gcp_dev1" {
  for_each            = { for each in local.gcp_dns_target_networks : each.cidr => each }
  name                = format("gcp-dev%s", (tonumber(element(split(".", google_compute_instance.dev_instance[each.value.cidr].network_interface.0.network_ip), 1)) + tonumber(element(split(".", google_compute_instance.dev_instance[each.value.cidr].network_interface.0.network_ip), 2)) + tonumber(element(split(".", google_compute_instance.dev_instance[each.value.cidr].network_interface.0.network_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [google_compute_instance.dev_instance[each.value.cidr].network_interface.0.network_ip]
}

resource "azurerm_private_dns_a_record" "gcp_dev2" {
  for_each            = { for each in local.gcp_dns_target_networks : each.cidr => each }
  name                = format("gcp-dev%s", (tonumber(element(split(".", google_compute_instance.dev_instance2[each.value.cidr].network_interface.0.network_ip), 1)) + tonumber(element(split(".", google_compute_instance.dev_instance2[each.value.cidr].network_interface.0.network_ip), 2)) + tonumber(element(split(".", google_compute_instance.dev_instance2[each.value.cidr].network_interface.0.network_ip), 3))) % 256)
  zone_name           = azurerm_private_dns_zone.cse_org.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [google_compute_instance.dev_instance2[each.value.cidr].network_interface.0.network_ip]
}



resource "azurerm_subnet" "inbound_resolver" {
  name                 = "inbound-dns-resolver"
  resource_group_name  = azurerm_resource_group.rg_name[0].name
  virtual_network_name = azurerm_virtual_network.vnet[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.vnet[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].address_space[0],12,4063)]
   delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet_route_table_association" "dns_resolver_rt_assoc" { 
  subnet_id               = azurerm_subnet.inbound_resolver.id
  route_table_id          = azurerm_route_table.private_spoke_rt_1[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id
}

resource "azurerm_private_dns_resolver" "dns_resolver" {
  name                = "dns-resolver"
  resource_group_name = azurerm_resource_group.rg_name[0].name
  location            = local.azure_spoke[0].region
  virtual_network_id  = azurerm_virtual_network.vnet[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound_endpoint" {
  name                    = "inbound-endpoint"
  private_dns_resolver_id = azurerm_private_dns_resolver.dns_resolver.id
  location                = azurerm_private_dns_resolver.dns_resolver.location
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id = azurerm_subnet.inbound_resolver.id
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  for_each                  = { for each in local.azure_spoke : each.cidr => each}
  name                      = azurerm_virtual_network.vnet[each.value.cidr].name
  resource_group_name       = azurerm_private_dns_zone.cse_org.resource_group_name
  private_dns_zone_name     = azurerm_private_dns_zone.cse_org.name
  virtual_network_id        = azurerm_virtual_network.vnet[each.value.cidr].id
}

resource "azurerm_private_dns_zone_virtual_network_link" "dsn_onprem_link" {
  name                      = "onprem-vnet"
  resource_group_name       = azurerm_private_dns_zone.cse_org.resource_group_name
  private_dns_zone_name     = azurerm_private_dns_zone.cse_org.name
  virtual_network_id        = azurerm_virtual_network.onprem.id
}


# AWS DNS Configuration

resource "aws_subnet" "aws_dns_resolver_1" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  vpc_id        = aws_vpc.aws_vpc[local.aws_spoke[0].cidr].id
  cidr_block    = cidrsubnet(aws_vpc.aws_vpc[local.aws_spoke[0].cidr].cidr_block, 12, 4063)
  availability_zone = format("%sa", local.aws_spoke[0].region)
  tags = {
    Name = "dns-outbound-endpoint-1"
  }
}

resource "aws_subnet" "aws_dns_resolver_2" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  vpc_id        = aws_vpc.aws_vpc[local.aws_spoke[0].cidr].id
  cidr_block    = cidrsubnet(aws_vpc.aws_vpc[local.aws_spoke[0].cidr].cidr_block, 12, 4062)
  availability_zone = format("%sb", local.aws_spoke[0].region)
  tags = {
    Name = "dns-inbound-endpoint-2"
  }
}

resource "aws_route_table_association" "dns_resolver_rt_1" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  subnet_id     = aws_subnet.aws_dns_resolver_1[0].id
  route_table_id = aws_route_table.aws_private_route_table_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id
}

resource "aws_route_table_association" "dns_resolver_rt_2" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  subnet_id     = aws_subnet.aws_dns_resolver_2[0].id
  route_table_id = aws_route_table.aws_private_route_table_2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id
}

resource "aws_route53_resolver_endpoint" "outbound_endpoint" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  name      = "aws-resolver"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.private_subnet_sg[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id
  ]

  ip_address {
    subnet_id = aws_subnet.aws_dns_resolver_1[0].id
    ip        = cidrhost(aws_subnet.aws_dns_resolver_1[0].cidr_block, 4)
  }

  ip_address {
    subnet_id = aws_subnet.aws_dns_resolver_2[0].id
    ip        = cidrhost(aws_subnet.aws_dns_resolver_2[0].cidr_block, 4)
  }

  tags = {
    Environment = "Prod"
  }
}

resource "aws_route53_resolver_rule" "to_azure_dns" {
  count         = length(local.aws_spoke) > 0 ? 1 : 0
  domain_name          = azurerm_private_dns_zone.cse_org.name
  name                 = "azure-dns"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound_endpoint[0].id

  target_ip {
    ip = azurerm_private_dns_resolver_inbound_endpoint.inbound_endpoint.ip_configurations[0].private_ip_address
  }

  tags = {
    Environment = "Prod"
  }
}

resource "aws_route53_resolver_rule_association" "rule_association" {
  for_each = { for each in local.aws_spoke : each.cidr => each }
  resolver_rule_id = aws_route53_resolver_rule.to_azure_dns[0].id
  vpc_id           = aws_vpc.aws_vpc[each.value.cidr].id
}




# GCP DNS Configuration
# GCP doesn't allow forwarding to a Private IP address over an NVA (Aviatrix Spoke Gateway); it only allows forwarding over Cloud Interconnect or Cloud VPN. The configuration below won't work but is left for reference.
# Ref - https://cloud.google.com/dns/docs/zones/forwarding-zones#firewall-rules

resource "google_dns_managed_zone" "private_zone" {
  count       = length(local.gcp_spoke) > 0 ? 1 : 0
  name        = "private-zone"
  dns_name    = "${azurerm_private_dns_zone.cse_org.name}."

  visibility = "private"

  private_visibility_config {    
      networks {      
        network_url = google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].id              
      }
    }

  forwarding_config {
    target_name_servers {
      ipv4_address = azurerm_private_dns_resolver_inbound_endpoint.inbound_endpoint.ip_configurations[0].private_ip_address
      forwarding_path = "private"
    }
  }
}

resource "google_dns_managed_zone" "peering_zone" {
  count       = length(local.gcp_spoke) > 1 ? 1 : 0
  name        = "peering-zone"
  dns_name    = "${azurerm_private_dns_zone.cse_org.name}."

  visibility = "private"

  private_visibility_config {    
      dynamic "networks" {
        for_each = local.gcp_dns_target_networks
        content {
          network_url = google_compute_network.gcp_vpc[networks.value.cidr].id
        }
      }
    }

  peering_config {
    target_network {
      network_url = google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].id        
    }
  } 
}

resource "google_compute_route" "azure_dns_resolver" {
  count       = length(local.gcp_spoke) > 0 ? 1 : 0
  name        = "azuredns"
  dest_range  = "${azurerm_private_dns_resolver_inbound_endpoint.inbound_endpoint.ip_configurations[0].private_ip_address}/32"
  network     = google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].name
  next_hop_ip = aviatrix_spoke_gateway.gcp-dns.private_ip
  priority    = 100
}

resource "google_compute_route" "azure_dnsha_resolver" {
  count       = length(local.gcp_spoke) > 0 ? 1 : 0
  name        = "azurednsha"
  dest_range  = "${azurerm_private_dns_resolver_inbound_endpoint.inbound_endpoint.ip_configurations[0].private_ip_address}/32"
  network     = google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].name
  next_hop_ip = aviatrix_spoke_ha_gateway.gcp-dns.private_ip
  priority    = 100
}


# Create Service Principal for Kubernetes External DNS

resource "random_id" "k8s" {
  byte_length = 4
}

resource "azuread_application" "k8s" {
  display_name = "k8s-${random_id.k8s.hex}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "k8s" {
  application_id               = azuread_application.k8s.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "k8s_password" {
  service_principal_id = azuread_service_principal.k8s.id
}

resource "time_sleep" "replication" {
 create_duration = "3m"
 triggers = {
  principal_id = azuread_service_principal.k8s.id
 }
}

resource "azurerm_role_assignment" "k8s_dns_contributor" {
  scope                = azurerm_private_dns_zone.cse_org.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = time_sleep.replication.triggers["principal_id"]
}

resource "azurerm_role_assignment" "k8s_rg_reader" {
  scope                = azurerm_resource_group.rg_name[0].id
  role_definition_name = "Reader"
  principal_id         = time_sleep.replication.triggers["principal_id"]
}