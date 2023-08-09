
# Enable DCF

resource "aviatrix_distributed_firewalling_config" "dcf" {
  enable_distributed_firewalling = true
}


resource "aviatrix_smart_group" "jumpbox" {
  name = "jumpbox"
  selector {
    match_expressions {
      type         = "vm"
      tags         = {
        environment = "bastion"
      }
    }
  }
}

resource "aviatrix_smart_group" "prod_smart_group" {
  name = "prod-smart-group"
  selector {
    match_expressions {
      type         = "vm"
      tags         = {
        environment = "prod"
      }
    }
  }
}

resource "aviatrix_smart_group" "dev_smart_group" {
  name = "dev-smart-group"
  selector {
    match_expressions {
      type         = "vm"
      tags         = {
        environment = "dev"
      }
    }
  }
}

resource "aviatrix_smart_group" "aks" {
  name = "aks"
  selector {
    match_expressions {
      cidr         = azurerm_subnet.private_subnet_2[var.azure_spoke_vnets[local.azure_transit[0]["region"]][0]].address_prefixes[0]
    }
  }
}

resource "aviatrix_smart_group" "gke_nodes" {
  name = "gke-nodes"
  selector {
    match_expressions {
      cidr         = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_transit[0]["region"]][0]].ip_cidr_range
    }
  }
}

resource "aviatrix_smart_group" "gke_pods" {
  name = "gke-pods"
  selector {
    match_expressions {
      cidr         = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_transit[0]["region"]][0]].secondary_ip_range.0.ip_cidr_range
    }
  }
}

resource "aviatrix_smart_group" "eks_nodes" {
  name = "eks-nodes"
  selector {
    match_expressions {
      cidr         = aws_subnet.eks_node_subnet_1[local.aws_spoke[0].cidr].cidr_block
    }
    match_expressions {
      cidr         = aws_subnet.eks_node_subnet_2[local.aws_spoke[0].cidr].cidr_block
    }
  }
}

resource "aviatrix_smart_group" "onprem_real" {
  name = "onprem-real"
  selector {
    match_expressions {
      cidr         = azurerm_subnet.onprem_vm.address_prefixes[0]
    }
  }
}

resource "aviatrix_smart_group" "onprem_nat" {
  name = "onprem-nat"
  selector {
    match_expressions {
      cidr         = "100.127.0.0/16"
    }
  }
}

#UPLOAD CERTIFICATES

resource "aviatrix_distributed_firewalling_proxy_ca_config" "dcf_ca_config" {
  lifecycle {
    ignore_changes = all
  }
  ca_cert = file("ca-chain.pem")
  ca_key  = file("intermediatekeydecrypted.pem")
}