variable "resource_group_name" {
  type = string
  default = "avxdcftest-rg"
}

variable "my_ipaddress" {
  type = string
  description = "IP address to allow SSH access to the jumpbox VM and OnPrem VM deployed in Azure. If you run this code from your laptop you can leave this field empty, the IP address of your computer will be retrieved by terraform"
  default = ""
}

variable "azure_spoke_vnets" {
  type = map(list(string))
  default = {
    "West US 2" =  ["10.10.0.0/16"]
}
  description = "One spoke VNET will be created for every object in the map. The key of the map is the region where the spoke VNET will be created. The value of the map is a list of CIDR blocks for the spoke VNETs in the region. At least one VNET in Azure is needed"
}

variable "azure_transit_vnets" {
  type = map(object({
    cidr  = string
    asn   = number
    gw_size = string
    firenet = optional(bool, false)
    hpe = optional(bool, false)
    bgpol = optional(bool, false)
    bgpol_int = optional(number, null)
    fw_image = optional(string, "")
    firewall_username = optional(string, "")
    firewall_password = optional(string, "")
  }))
  default = {
    "West US 2" = {
        "cidr" = "10.19.0.0/16",
        "asn" = 64510,
        "gw_size" = "Standard_D8_v5"
    }
  }
  description = "One transit VNET will be created for every object in the map. The key of the map is the region where the transit VNET will be created. The value of the map is some of the attributes for mc-transit module. At least one VNET in Azure is needed"
}

variable "aws_spoke_vnets" {
  type = map(list(string))
  default = {
    "us-west-2" = ["10.20.0.0/16"]
  }
  description = "One spoke VPC will be created for every object in the map. The key of the map is the region where the VPC will be created, the list of CIDRs is the CIDR used for every VPC. At least one VPC in AWS is needed"
}

variable "aws_transit_vnets" {
  type = map(object({
    cidr  = string
    asn   = number
    gw_size = string
    firenet = optional(bool, false)
    hpe = optional(bool, false)
    fw_image = optional(string, "")
  }))
  default = {
    "us-west-2" = {
        "cidr" = "10.29.0.0/16",
        "asn" = 64520,
        "gw_size" = "c5.xlarge"
    }
  }
  description = "One transit VPC will be created for every object in the map. The value of the map is some of the attributes for mc-transit module. At least one VPC in AWS is needed"
}

variable "gcp_spoke_vnets" {
  type = map(list(string))
  default = {
    "us-west1" = ["10.30.0.0/16","10.31.0.0/16"]
  }
  description = "One spoke VPC will be created for every object in the map. The key of the map is the region where the VPC will be created, the list of CIDRs is the CIDR used for every VPC. At least one VPC in GCP is needed. If only one VPC is created, only the GKE worker nodes will be created but no instances will be created. Instances are only created starting from the second VPC in the list"
}

variable "gcp_transit_vnets" {
   type = map(object({
    cidr  = string
    asn   = number
    gw_size = string
    firenet = optional(bool, false)
    fw_image = optional(string, "")
    firenet_mgmt_cidr = optional(string, "")
    firenet_egress_cidr = optional(string, "")
    lan_cidr = optional(string, "")
    hpe = optional(bool, false)
    bgpol = optional(bool, false)
    bgpol_int = optional(list(object(
    {
      vpc_id     = optional(string, "")
      subnet     = string,
      create_vpc = optional(bool, false)
    }
    )), [])
    ha_bgpol_int = optional(list(object(
    {
      vpc_id     = optional(string, "")
      subnet     = string,
      create_vpc = optional(bool, false)
    }
    )), [])
  }))
  default= {
    "us-west1" = {
        "cidr" =  "10.39.0.0/16",
        "asn" = 64530,
        "gw_size" = "n1-standard-4"
    }
  }
  description = "One transit VPC will be created for every object in the map. The value of the map is some of the attributes for mc-transit module. At least one VPC in GCP is needed"
}

variable "azure_vmSKU" {
  type = string
  default = "Standard_B2ms"
  description = "SKU for the VMs in Azure for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete"
}

variable "aws_vmSKU" {
  type = string
  default = "t3.small"
  description = "SKU for the VMs in AWS for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete"
}

variable "gcp_vmSKU" {
  type = string
  default = "e2-standard-2"
  description = "SKU for the VMs in GCP for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete"
}

variable "azure_spoke_gw_sku" {
  type = string
  default = "Standard_D2_v5"
}

variable "aws_spoke_gw_sku" {
  type = string
  default = "t3.medium"
}

variable "gcp_spoke_gw_sku" {
  type = string
  default = "n1-standard-2"
}

variable "azure_vm_admin_username" {
    type = string
    description = "This is the username used to SSH into the jumpbox and OnPrem VM deployed in Azure"
    default = "avxuser"
}

variable "ssh_public_key_file" {
    type = string
    description = "This is the path to the SSH public key file used to SSH into all of the VMs deployed across all clouds, including the kubernetes worker nodes"
}

variable "azure_account" {
  type = string
  description = "Account created on the Aviatrix Controller for Azure deployments"
}

variable "aws_account" {
  type = string
  description = "Account created on the Aviatrix Controller for AWS deployments"
}

variable "gcp_account" {
  type = string
  description = "Account created on the Aviatrix Controller for GCP deployments"
}

variable "k8s_cluster_name" {
  type = string
  default = "k8s-cluster"
  description = "Suffix used to create the K8S managed clusters in the different clouds. They will be prepended the CSP K8S 3 letter code (aks, eks, gke)"
}

variable "aks_sevice_cidr" {
  type = string
  default = "172.16.255.0/24"
  description = "CIDR range used for AKS services"
}

variable "aks_vm_sku" {
  type = string
  default = "Standard_D2_v5"
  description = "SKU for the AKS worker nodes"
}

variable "eks_vm_sku" {
  type = string
  default = "t3.large"
  description = "SKU for the EKS worker nodes"
}

variable "gke_vm_sku" {
  type = string
  default = "n2-standard-2"
  description = "SKU for the GKE worker nodes"
}

variable "gke_pod_cidr" {
  type = string
  default = "172.16.0.0/14"
  description = "CIDR used for the pods in GKE"
}

variable "gke_svc_cidr" {
  type = string
  default = "172.21.0.0/19"
  description = "CIDR used for the services in GKE"
}

variable "on_prem_cidr" {
  type = string
  default = null
  description = "CIDR used for the VNET in Azure used to simulate on premises"
}

variable "s2c_spoke_cidr" {
  type = string
  default = "10.15.0.0/16"
  description = "CIDR used for the spoke VNET in Azure where S2C is terminated"
}

variable "s2c_nat" {
  type = string
  validation {
    condition     = can(regex("(?i)^(custom|mapped)$", var.s2c_nat))
    error_message = "The input variable must be 'custom' or 'mapped', case-insensitive."
  }
  default = "custom"
  description = "Type of NAT configured for S2C. If s2c_routing is set to BGP this varialbe is ignored, only custom NAT is supported with BGP"
}

variable "s2c_routing" {
  type = string
  validation {
    condition     = can(regex("(?i)^(bgp|static)$", var.s2c_routing))
    error_message = "The input variable must be 'bgp' or 'static', case-insensitive."
  }
  default = "static"
  description = "Type of routing configured for S2C"
}

variable "s2c_avx_bgp_asn" {
  type = number
  default = 64900
  description = "BGP ASN used for the Aviatrix spoke gateway in Azure that terminates the S2C tunnel"
}

variable "s2c_onprem_bgp_asn" {
  type = number
  default = 64800
  description = "BGP ASN used for the on premises NVA that terminates the S2C tunnel"
}

variable "s2c_tunnel_cidr" {
  type = string
  description = "The CIDR block for the tunnel interface. /29 is required because two tunnels are needed"
  default = "169.254.255.248/29"
}

variable "internal_dns_zone" {
  type = string
  description = "Name of the Azure Private DNS Zone that will be created. Records for all deployments will be added in this zone"
  default = "aviatrix.internal"
}

locals {
    azure_spoke = flatten([
        for region_key, azure_region in var.azure_spoke_vnets : [
            for vnet_cidr in azure_region : {
                region      = region_key
                cidr        = vnet_cidr
                vnet_name   = replace(vnet_cidr,".","-")
            }
        ]
    ])

  azure_transit = [
    for region_key, azure_region in var.azure_transit_vnets : {
      region  = region_key
      cidr    = azure_region.cidr
      bgp_asn = azure_region.asn
      gw_size = azure_region.gw_size
      firenet = azure_region.firenet
      fw_image = azure_region.fw_image
      fw_username = azure_region.firewall_username
      fw_password = azure_region.firewall_password
      hpe     = azure_region.hpe
      bgpol   = azure_region.bgpol
      bgpol_int = azure_region.bgpol_int
    }
  ]

    aws_spoke = flatten([
        for region_key, aws_region in var.aws_spoke_vnets : [
            for vnet_cidr in aws_region : {
                region      = region_key
                cidr        = vnet_cidr
                vnet_name   = replace(vnet_cidr,".","-")
            }
        ]
    ])
    aws_transit = [
    for region_key, aws_region in var.aws_transit_vnets : {
      region  = region_key
      cidr    = aws_region.cidr
      bgp_asn = aws_region.asn
      gw_size = aws_region.gw_size
      firenet = aws_region.firenet
      fw_image = aws_region.fw_image
      hpe     = aws_region.hpe
    }
  ]

    gcp_spoke = flatten([
        for region_key, gcp_region in var.gcp_spoke_vnets : [
            for vnet_cidr in gcp_region : {
                region      = region_key
                cidr        = vnet_cidr
                vnet_name   = replace(vnet_cidr,".","-")
            }
        ]
    ])
    gcp_transit = [
    for region_key, gcp_region in var.gcp_transit_vnets : {
      region  = region_key
      cidr    = gcp_region.cidr
      bgp_asn = gcp_region.asn
      gw_size = gcp_region.gw_size
      firenet = gcp_region.firenet
      lan_cidr = gcp_region.lan_cidr
      fw_image = gcp_region.fw_image
      mgmt_cidr = gcp_region.firenet_mgmt_cidr
      egress_cidr = gcp_region.firenet_egress_cidr
      hpe     = gcp_region.hpe
      bgpol   = gcp_region.bgpol
      bgpol_int = gcp_region.bgpol_int
      ha_bgpol_int = gcp_region.ha_bgpol_int
    }
  ]

  azure_vnet_list = [ for region in local.azure_spoke : region.cidr ]
  aws_vpc_list = [ for region in local.aws_spoke : region.cidr ]
  gcp_vpc_list = [ for region in local.gcp_spoke : region.cidr ]

  azure_transit_list = [ for region in local.azure_transit : module.azure-transit[region.region].transit_gateway.gw_name ]
  aws_transit_list = [ for region in local.aws_transit : module.aws-transit[region.region].transit_gateway.gw_name ]
  gcp_transit_list = [ for region in local.gcp_transit : module.gcp-transit[region.region].transit_gateway.gw_name ]

  azure_aws_transit_pairs = flatten([
    for az in local.azure_transit : [
      for aws in local.aws_transit : {
        az  = az
        aws = aws
      }
    ]
  ])

  azure_gcp_transit_pairs = flatten([
    for az in local.azure_transit : [
      for gcp in local.gcp_transit : {
        az  = az
        gcp = gcp
      }
    ]
  ])

  aws_gcp_transit_pairs = flatten([
    for aws in local.aws_transit : [
      for gcp in local.gcp_transit : {
        aws  = aws
        gcp = gcp
      }
    ]
  ])

  gcp_dns_target_networks = slice(local.gcp_spoke, 1, length(local.gcp_spoke))

  on_prem_cidr = var.on_prem_cidr == null ? local.azure_spoke[0].cidr : var.on_prem_cidr
  tunnel1_cidr = cidrsubnet(var.s2c_tunnel_cidr, 1, 0)
  tunnel2_cidr = cidrsubnet(var.s2c_tunnel_cidr, 1, 1)
}