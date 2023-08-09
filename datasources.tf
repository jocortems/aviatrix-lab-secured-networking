
# General

data "azurerm_subscription" "current" {}

data "google_project" "current" {}

data "google_client_config" "provider" {}

data "http" "my_ip" {
    url = "http://ipv4.icanhazip.com/"
    method = "GET"
}


# AKS
resource "time_sleep" "aks_service_load_balancer_provisioning" {
  create_duration = "5m"
  depends_on = [ 
    kubernetes_service.myipapp_service,
    kubernetes_service.aks_getcerts_service
    ]
}

resource "time_sleep" "aks_ingress_load_balancer_provisioning" {
  create_duration = "5m"
  depends_on = [ 
    kubernetes_ingress_v1.myipapp_ingress,
    kubernetes_service.aks_getcerts_service
    ]
}

data "azurerm_private_dns_a_record" "aks_myipapp_service" {
  depends_on = [ 
    time_sleep.aks_service_load_balancer_provisioning
   ]
   name = kubernetes_service.myipapp_service.metadata[0].name
   zone_name = azurerm_private_dns_zone.cse_org.name
   resource_group_name = azurerm_resource_group.rg_name[0].name
}

data "azurerm_private_dns_a_record" "aks_myipapp_ingress" {
  depends_on = [ 
    time_sleep.aks_ingress_load_balancer_provisioning
   ]
  name = kubernetes_ingress_v1.myipapp_ingress.metadata[0].name
  zone_name = azurerm_private_dns_zone.cse_org.name
  resource_group_name = azurerm_resource_group.rg_name[0].name
}

data "azurerm_private_dns_a_record" "aks_getcerts_service" {
  depends_on = [ 
    time_sleep.aks_service_load_balancer_provisioning
   ]
   name = kubernetes_service.aks_getcerts_service.metadata[0].name
   zone_name = azurerm_private_dns_zone.cse_org.name
   resource_group_name = azurerm_resource_group.rg_name[0].name
}


# GKE
resource "time_sleep" "gke_service_load_balancer_provisioning" {
  create_duration = "5m"

  depends_on = [ 
    kubernetes_service.gke_myipapp_service,
    kubernetes_service.gke_getcerts_service
  ]
}

resource "time_sleep" "gke_ingress_load_balancer_provisioning" {
  create_duration = "5m"

  depends_on = [ 
    kubernetes_ingress_v1.gke_myipapp_ingress,
    kubernetes_service.gke_getcerts_service
    ]
}

data "azurerm_private_dns_a_record" "gke_myipapp_service" {
  depends_on = [ 
    time_sleep.gke_service_load_balancer_provisioning
   ]
   name = kubernetes_service.gke_myipapp_service.metadata[0].name
   zone_name = azurerm_private_dns_zone.cse_org.name
   resource_group_name = azurerm_resource_group.rg_name[0].name
}

data "azurerm_private_dns_a_record" "gke_myipapp_ingress" {
  depends_on = [ 
    time_sleep.gke_ingress_load_balancer_provisioning
   ]
  name = kubernetes_ingress_v1.gke_myipapp_ingress.metadata[0].name
  zone_name = azurerm_private_dns_zone.cse_org.name
  resource_group_name = azurerm_resource_group.rg_name[0].name
}

data "azurerm_private_dns_a_record" "gke_getcerts_service" {
  depends_on = [ 
    time_sleep.gke_service_load_balancer_provisioning
   ]
   name = kubernetes_service.gke_getcerts_service.metadata[0].name
   zone_name = azurerm_private_dns_zone.cse_org.name
   resource_group_name = azurerm_resource_group.rg_name[0].name
}


# EKS
data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.27-*"]
  }
}

# AWS
data "aws_ami" "ubuntu20_04" {
  most_recent = true
  owners = ["099720109477"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

# Azure
data "azuread_client_config" "current" {}

