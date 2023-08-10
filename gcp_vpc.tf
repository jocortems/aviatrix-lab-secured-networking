resource "google_compute_network" "gcp_vpc" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("vpc-%s", replace(each.value.vnet_name, "/", "-"))
  auto_create_subnetworks = false
  delete_default_routes_on_create = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "aviatrix_primary_gw" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("avx-gw-%s", replace(each.value.vnet_name, "/", "-"))
  ip_cidr_range = cidrsubnet(each.value.cidr, 8, 255)
  region = each.value.region
  network = google_compute_network.gcp_vpc[each.value.cidr].id
}

resource "google_compute_subnetwork" "aviatrix_ha_gw" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("avx-hagw-%s", replace(each.value.vnet_name, "/", "-"))
  ip_cidr_range = cidrsubnet(each.value.cidr, 8, 254)
  region = each.value.region
  network = google_compute_network.gcp_vpc[each.value.cidr].id
}

resource "google_compute_subnetwork" "gcp_private_subnet_1" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("private1-%s", replace(each.value.vnet_name, "/", "-"))
  ip_cidr_range = cidrsubnet(each.value.cidr, 8, 10)
  region = each.value.region
  network = google_compute_network.gcp_vpc[each.value.cidr].id
}

resource "google_compute_subnetwork" "gcp_private_subnet_2" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("private2-%s", replace(each.value.vnet_name, "/", "-"))
  ip_cidr_range = cidrsubnet(each.value.cidr, 8, 15)
  region = each.value.region
  network = google_compute_network.gcp_vpc[each.value.cidr].id
}

resource "google_compute_subnetwork" "gcp_private_subnet_3" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("private3-%s", replace(each.value.vnet_name, "/", "-"))
  ip_cidr_range = cidrsubnet(each.value.cidr, 4, 1)
  secondary_ip_range {
    range_name = "gke-pods"
    ip_cidr_range = var.gke_pod_cidr
  }
  secondary_ip_range {
    range_name = "gke-service"
    ip_cidr_range = var.gke_svc_cidr
  }
  region = each.value.region
  network = google_compute_network.gcp_vpc[each.value.cidr].id
}

resource "google_compute_firewall" "gcp_firewall" {
  for_each = { for each in local.gcp_spoke : each.cidr => each }
  name = format("gcp-fw-%s", replace(each.value.vnet_name, "/", "-"))
  network = google_compute_network.gcp_vpc[each.value.cidr].id
  allow {
    protocol = "all"
  }
  source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
}


resource "google_compute_instance" "prod_instance" {
    for_each = { for each in local.gcp_dns_target_networks : each.cidr => each }
    name = format("gcp-prod1-%s", replace(each.value.vnet_name, "/", "-"))
    machine_type = var.gcp_vmSKU
    zone = format("%s-a", each.value.region)
    metadata = {
        ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
        startup-script = file("cloud-init.sh")
    }
    boot_disk {
        initialize_params {
        image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
        }
    }
    network_interface {
        subnetwork = google_compute_subnetwork.gcp_private_subnet_1[each.value.cidr].id
        network_ip = cidrhost(google_compute_subnetwork.gcp_private_subnet_1[each.value.cidr].ip_cidr_range, 11)
    }
    tags = ["avx-snat-noip"]    
    labels = {
        "environment" = "prod"
        avx_spoke = aviatrix_spoke_transit_attachment.gcp_uswest1[each.value.cidr].spoke_gw_name
    }
}

resource "google_compute_instance" "prod_instance2" {
    for_each = { for each in local.gcp_dns_target_networks : each.cidr => each }
    name = format("gcp-prod2-%s", replace(each.value.vnet_name, "/", "-"))
    machine_type = var.gcp_vmSKU
    zone = format("%s-a", each.value.region)
    metadata = {
        ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
        startup-script = file("cloud-init.sh")
    }
    boot_disk {
        initialize_params {
        image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
        }
    }
    network_interface {
        subnetwork = google_compute_subnetwork.gcp_private_subnet_2[each.value.cidr].id
        network_ip = cidrhost(google_compute_subnetwork.gcp_private_subnet_2[each.value.cidr].ip_cidr_range, 11)
    }
    tags = ["avx-snat-noip"]    
    labels = {
        "environment" = "prod"
        avx_spoke = aviatrix_spoke_transit_attachment.gcp_uswest1[each.value.cidr].spoke_gw_name
    }
}

resource "google_compute_instance" "dev_instance" {
    for_each = { for each in local.gcp_dns_target_networks : each.cidr => each }
    name = format("gcp-dev1-%s", replace(each.value.vnet_name, "/", "-"))
    machine_type = var.gcp_vmSKU
    zone = format("%s-a", each.value.region)
    metadata = {
        ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
        startup-script = file("cloud-init.sh")
    }
    boot_disk {
        initialize_params {
        image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
        }
    }
    network_interface {
        subnetwork = google_compute_subnetwork.gcp_private_subnet_2[each.value.cidr].id
        network_ip = cidrhost(google_compute_subnetwork.gcp_private_subnet_2[each.value.cidr].ip_cidr_range, 21)
    }
    tags = ["avx-snat-noip"]    
    labels = {
        "environment" = "dev"
        avx_spoke = aviatrix_spoke_transit_attachment.gcp_uswest1[each.value.cidr].spoke_gw_name
    }
}

resource "google_compute_instance" "dev_instance2" {
    for_each = { for each in local.gcp_dns_target_networks : each.cidr => each }
    name = format("gcp-dev2-%s", replace(each.value.vnet_name, "/", "-"))
    machine_type = var.gcp_vmSKU
    zone = format("%s-a", each.value.region)
    metadata = {
        ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
        startup-script = file("cloud-init.sh")
    }
    boot_disk {
        initialize_params {
        image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
        }
    }
    network_interface {
        subnetwork = google_compute_subnetwork.gcp_private_subnet_1[each.value.cidr].id
        network_ip = cidrhost(google_compute_subnetwork.gcp_private_subnet_1[each.value.cidr].ip_cidr_range, 21)
    }
    tags = ["avx-snat-noip"]    
    labels = {
        "environment" = "dev"
        avx_spoke = aviatrix_spoke_transit_attachment.gcp_uswest1[each.value.cidr].spoke_gw_name
    }
}