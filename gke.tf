resource "google_container_cluster" "primary" {
  count = length(local.gcp_spoke) > 0 ? 1 : 0
  lifecycle {
    ignore_changes = [
      min_master_version
    ]
  }
  name     = "${var.k8s_cluster_name}-gke"
  location = "${local.gcp_transit[0]["region"]}-a"
  min_master_version = "1.27"
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  resource_labels = {
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.gcp_dns_att.spoke_gw_name
  }

  networking_mode = "VPC_NATIVE"

  network    = google_compute_network.gcp_vpc[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].name
  subnetwork = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].name

  ip_allocation_policy {
    cluster_secondary_range_name = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].secondary_ip_range.0.range_name
    services_secondary_range_name = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].secondary_ip_range.1.range_name
  }  
}

# Separately Managed Node Pool
resource "google_container_node_pool" "prod_nodes" {
  lifecycle {
    ignore_changes = [
      version
    ]
  }
  name       = "prod-node-pool"
  location   = google_container_cluster.primary[0].location
  cluster    = google_container_cluster.primary[0].name
  node_count = 2
  version    = "1.27"

  node_config {
    image_type = "UBUNTU_CONTAINERD"
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    resource_labels = {
      environment = "prod"
    }
    labels = {
      "prod-node" = "true"
    }
    machine_type = "n2-standard-2"
    tags         = ["prod", "gke-node", "avx-snat-noip"]
    metadata = {
      disable-legacy-endpoints = "true"
      ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
    }
  }
  
  network_config {
    enable_private_nodes = true
    create_pod_range     = false
    pod_range            = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].secondary_ip_range.0.range_name
  }
}


resource "google_container_node_pool" "dev_nodes" {
  lifecycle {
    ignore_changes = [
      version
    ]
  }
  name       = "dev-node-pool"
  location   = google_container_cluster.primary[0].location
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = "1.27"

  node_config {
    image_type = "UBUNTU_CONTAINERD"
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    resource_labels = {
      environment = "dev"
    }
    labels = {
      "dev-node" = "true"
    }
    machine_type = var.gke_vm_sku
    tags         = ["dev", "gke-node", "avx-snat-noip"]
    metadata = {
      disable-legacy-endpoints = "true"
      ssh-keys = "${var.azure_vm_admin_username}:${file(var.ssh_public_key_file)}"
    }
    taint {
      key    = "environment"
      value  = "dev"
      effect = "NO_SCHEDULE"
    }
  }
  
  network_config {
    enable_private_nodes = true
    create_pod_range     = false
    pod_range            = google_compute_subnetwork.gcp_private_subnet_3[var.gcp_spoke_vnets[local.gcp_spoke[0].region][0]].secondary_ip_range.0.range_name
  }
}

provider "kubernetes" {
  alias = "gke"
  host                   = "https://${google_container_cluster.primary[0].endpoint}"
  token                  = data.google_client_config.provider.access_token
  client_certificate     = base64decode(google_container_cluster.primary[0].master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.primary[0].master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.primary[0].master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  alias = "gke"
  kubernetes {
    host                   = "https://${google_container_cluster.primary[0].endpoint}"
    token                  = data.google_client_config.provider.access_token
    client_certificate     = base64decode(google_container_cluster.primary[0].master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary[0].master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary[0].master_auth.0.cluster_ca_certificate)
  }
}

resource "helm_release" "gke_certmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes ,
    kubernetes_namespace.gke_certmanager,
  ]
  provider   = helm.gke
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.12.3"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "gke_trustmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes ,
    kubernetes_namespace.gke_certmanager,
    helm_release.gke_certmanager
  ]
  provider   = helm.gke
  name       = "trust-manager"
  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"
  namespace  = "cert-manager"
  version    = "v0.5.0"
}

resource "kubernetes_namespace" "gke_certmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes    
  ]
  provider = kubernetes.gke
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_secret_v1" "gke_certmanager_ca" {
  provider = kubernetes.gke
  metadata {
    name      = "ca-clusterissuer"
    namespace = kubernetes_namespace.gke_certmanager.metadata[0].name
  }
  data = {
    "tls.crt" = trimspace(file("ca-chain.pem"))
    "tls.key" = trimspace(file("intermediatekeydecrypted.pem"))
  }
}

resource "helm_release" "gke_nginx_ingress" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes    
  ]
  provider   = helm.gke
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "kube-system"
  
  set {
    name = "controller.service.annotations.cloud\\.google\\.com/load-balancer-type"
    value = "Internal"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }
}

resource "kubernetes_namespace" "gke_dev" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes    
  ]
  provider = kubernetes.gke
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "gke_prod" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes    
  ]
  provider = kubernetes.gke
  metadata {
    name = "prod"
  }
}

resource "kubernetes_deployment_v1" "gke_myipapp_deployment" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations ,
    google_container_node_pool.prod_nodes 
  ]
  provider = kubernetes.gke
  metadata {
    name = "myipapp-deployment"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "myipapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "myipapp"
        }
      }

      spec {
        container {
          name  = "myipapp-container"
          image = "jorgecortesdocker/myipapp:v4"

          port {
            container_port = 8080
          }
          volume_mount {
            name       = "ca-bundle"
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
            sub_path = "ca-bundle.pem"
            read_only = true
          }
          env {
            name = "PORT"
            value = 8080
          }
        }
        volume {
          name = "ca-bundle"
          config_map {
            name = "ca-bundle"
          }
        }
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "prod-node"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["myipapp"]
                  }
                }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
        }
      }
    }
  }
}

resource "kubernetes_deployment_v1" "gke_getcerts" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes,
    null_resource.gke_certmanager
  ]
  provider = kubernetes.gke
  metadata {
    name = "gke-getcerts"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "getcerts"
      }
    }

    template {
      metadata {
        labels = {
          app = "getcerts"
        }
      }

      spec {
        container {
          name  = "getcerts-container"
          image = "jorgecortesdocker/gettlscerts:v2"
          port {
            container_port = 5000
          }
          volume_mount {
            name       = "ca-bundle"
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
            sub_path = "ca-bundle.pem"
            read_only = true
          }
          env {
            name = "PORT"
            value = 5000
          }
        }
        volume {
          name = "ca-bundle"
          config_map {
            name = "ca-bundle"
          }
        }
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "prod-node"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["getcerts"]
                  }
                }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
        }
      }
    }
  }
}

resource "kubernetes_pod_v1" "gke_dev_pod" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.dev_nodes 
  ]

  provider = kubernetes.gke

  metadata {
    name = "dev-pod"
    namespace = kubernetes_namespace.gke_dev.metadata[0].name
  }

  spec {
    container {
      name  = "ubuntu"
      image = "ecpe4s/ubuntu22.04-runner-x86_64:2023-01-01"

      # Add a command that sleeps for a very long time
      command = ["/bin/sh", "-c", "sleep 1000000"]

      env {
        name = "CURL_CA_BUNDLE"
        value = "/etc/ssl/certs/ca-certificates.crt"
      }      

      env {
        name = "SSL_CERT_FILE"
        value = "/etc/ssl/certs/ca-certificates.crt"
      }

      env {
        name = "SSL_CERT_DIR"
        value = "/etc/ssl/certs/"
      }

      volume_mount {
        name       = "ca-bundle"
        mount_path = "/etc/ssl/certs/ca-certificates.crt"
        sub_path = "ca-bundle.pem"
        read_only = true
      }
    }

    volume {
      name = "ca-bundle"
      config_map {
        name = "ca-bundle"
      }
    }

    toleration {
          effect   = "NoSchedule"
          operator = "Exists"
        }

    affinity {
      node_affinity {
        required_during_scheduling_ignored_during_execution {
          node_selector_term {
            match_expressions {
              key      = "dev-node"
              operator = "In"
              values   = ["true"]
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "gke_myipapp_service" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations ,
    google_container_node_pool.prod_nodes,
    kubernetes_deployment_v1.gke_externaldns 
  ]
  provider = kubernetes.gke
  metadata {
    name = "gke-myip-svc"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "external-dns.alpha.kubernetes.io/hostname" = "gke-myip-svc.${azurerm_private_dns_zone.cse_org.name}"
    }
  }

  spec {
    selector = {
      app = "myipapp"
    }

    type = "LoadBalancer"
    external_traffic_policy = "Local"

    port {
      name       = "myipapp-port"
      protocol   = "TCP"
      port       = 8080
      target_port = 8080
    }
  }  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "kubernetes_service" "gke_getcerts_service" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes,
    kubernetes_deployment_v1.aks_externaldns,
    null_resource.gke_certmanager
  ]
  provider = kubernetes.gke
  metadata {
    name = "gke-getcerts-svc"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "external-dns.alpha.kubernetes.io/hostname" = "gke-getcerts-svc.${azurerm_private_dns_zone.cse_org.name}"
    }
  }

  spec {
    selector = {
      app = "getcerts"
    }

    type = "LoadBalancer"
    external_traffic_policy = "Local"

    port {
      name       = "getcerts-port"
      protocol   = "TCP"
      port       = 5000
      target_port = 5000
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}


resource "kubernetes_secret_v1" "gke_cacert" {
  depends_on = [ 
    google_container_node_pool.dev_nodes 
  ]
  provider = kubernetes.gke
  metadata {
    name      = "cacert"
    namespace = "kube-system"
  }
  type = "Opaque"
  data = {
    "cacert.crt" = trimspace(file("ca-chain.pem"))
  }
}

resource "kubernetes_config_map_v1" "gke_load_certs_script" {
  depends_on = [ 
    google_container_node_pool.dev_nodes 
  ]
  provider = kubernetes.gke
  metadata {
    name      = "load-certs-script"
    namespace = "kube-system"
  }

  data = {
    "load-certs.sh" = <<EOF
#!/usr/bin/env bash
set -x

echo "Copying the custom root certificate"
cp /cacert/cacert.crt /mnt/usr/local/share/ca-certificates/cacert.crt
echo "Certificates copied"
nsenter --target 1 --mount update-ca-certificates
nsenter --target 1 --mount bash -c "systemctl is-active --quiet containerd && echo 'Restarting containerd' && systemctl restart containerd"
EOF
  }
}

resource "kubernetes_daemon_set_v1" "gke_cert_customizations" {
  depends_on = [ 
    google_container_node_pool.dev_nodes 
  ]
  provider = kubernetes.gke
  metadata {
    name      = "cert-customizations"
    namespace = "kube-system"

    labels = {
      app = "cert-customizations"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "cert-customizations"
      }
    }

    template {
      metadata {
        labels = {
          app = "cert-customizations"
        }
      }

      spec {
        priority_class_name = "system-node-critical"
        host_network        = true
        host_pid            = true

        init_container {
          name  = "cert-customizations"
          image = "ecpe4s/ubuntu22.04-runner-x86_64:2023-01-01"

          command = ["/scripts/load-certs.sh"]

          volume_mount {
            name       = "usr"
            mount_path = "/mnt/usr"
          }

          volume_mount {
            name       = "cacert"
            mount_path = "/cacert"
            read_only  = true
          }

          volume_mount {
            name       = "scripts"
            mount_path = "/scripts"
          }

          security_context {
            privileged = true

            capabilities {
              add = ["NET_ADMIN"]
            }
          }
        }

        volume {
          name = "usr"

          host_path {
            path = "/usr"
          }
        }

        volume {
          name = "scripts"

          config_map {
            name         = kubernetes_config_map_v1.gke_load_certs_script.metadata[0].name
            default_mode = "0744"
          }
        }

        volume {
          name = "cacert"

          secret {
            secret_name  = kubernetes_secret_v1.gke_cacert.metadata[0].name
            default_mode = "0420"
          }
        }

        container {
          name  = "pause"
          image = "google/pause"
        }

        toleration {
          effect   = "NoSchedule"
          operator = "Exists"
        }
      }
    }
  }
}





resource "null_resource" "gke_credentials" {
  depends_on = [ 
    google_container_node_pool.prod_nodes,
    null_resource.aks_credentials,
    null_resource.aks_certmanager
  ]
  provisioner "local-exec" {
    command = <<EOF
    gcloud container clusters get-credentials ${google_container_cluster.primary[0].name} --zone ${google_container_cluster.primary[0].location}
    EOF
  }
}

resource "time_sleep" "gke_wait_for_webhook_servers" {
  depends_on = [ 
    null_resource.gke_credentials,
    kubernetes_secret_v1.gke_certmanager_ca,
    helm_release.gke_certmanager,
    helm_release.gke_trustmanager,
    helm_release.gke_nginx_ingress
  ]
  create_duration = "3m"
}

resource "null_resource" "gke_certmanager" {
  depends_on = [ 
    time_sleep.gke_wait_for_webhook_servers
  ]
  provisioner "local-exec" {
    command = <<EOF
    kubectl apply -f certmanager.yaml
    EOF
  }
}

resource "kubernetes_ingress_v1" "gke_myipapp_ingress" {
  depends_on = [ 
    null_resource.gke_certmanager,
    kubernetes_deployment_v1.gke_externaldns
  ]
  provider = kubernetes.gke
  metadata {
    name = "gke-ingress"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "cert-manager.io/cluster-issuer"             = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    rule {
      host = "gke-ingress.${azurerm_private_dns_zone.cse_org.name}"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.gke_myipapp_service.metadata[0].name
              port {
                number = 8080
              }
            }
          }
          path       = "/api/ip"
          path_type  = "Prefix"
        }
        path {
          backend {
            service {
              name = kubernetes_service.gke_getcerts_service.metadata[0].name
              port {
                number = 5000
              }
            }
          }
          path       = "/api/tls(/|$)(.*)"
          path_type  = "Prefix"
        }
      }
    }
    tls {
      hosts = ["gke-ingress.${azurerm_private_dns_zone.cse_org.name}"]
      secret_name = kubernetes_secret_v1.gke_certmanager_ca.metadata[0].name
    }
  }
}

# External DNS Configuration

resource "kubernetes_secret_v1" "gke_externaldns" {
  depends_on = [
    azurerm_role_assignment.k8s_dns_contributor,
    azurerm_role_assignment.k8s_rg_reader
  ]
  provider = kubernetes.gke
  metadata {
    name = "k8s-dns"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
  }
  type = "Opaque"
  data = {
    "azure.json" = jsonencode({
      "tenantId"         = "${data.azurerm_subscription.current.tenant_id}"
      "subscriptionId"   = "${data.azurerm_subscription.current.subscription_id}"
      "resourceGroup"    = "${azurerm_resource_group.rg_name[0].name}"
      "aadClientId"      = "${azuread_service_principal.k8s.client_id}"
      "aadClientSecret"  = "${azuread_service_principal_password.k8s_password.value}"
    })
  }
}

resource "kubernetes_cluster_role_v1" "gke_external_dns" {
  provider = kubernetes.gke
  metadata {
    name = "external-dns"
  }

  rule {
    api_groups = [""]
    resources  = ["services","endpoints","pods", "nodes"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions","networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "gke_external_dns_viewer" {
  provider = kubernetes.gke
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.gke_external_dns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.gke_external_dns.metadata[0].name
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
  }
}

resource "kubernetes_service_account_v1" "gke_external_dns" {
  provider = kubernetes.gke
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
  }
}



resource "kubernetes_deployment_v1" "gke_externaldns" {
  depends_on = [ 
    kubernetes_daemon_set_v1.gke_cert_customizations,
    google_container_node_pool.prod_nodes,
  ]
  provider = kubernetes.gke
  metadata {
    name = "externaldns"
    namespace = kubernetes_namespace.gke_prod.metadata[0].name
    labels = {
      app = "externaldns"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "externaldns"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "externaldns"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.gke_external_dns.metadata[0].name
        container {
          image = "registry.k8s.io/external-dns/external-dns:v0.13.5"
          name  = "externaldns"
          
          args = [
            "--source=service",
            "--source=ingress",
            "--domain-filter=${azurerm_private_dns_zone.cse_org.name}",
            "--provider=azure-private-dns",
            "--azure-resource-group=${azurerm_resource_group.rg_name[0].name}",
            "--azure-subscription-id=${data.azurerm_subscription.current.subscription_id}",
            "--txt-prefix=gketxt-"
          ]

          volume_mount {
            name       = "azure-config-file"
            mount_path = "/etc/kubernetes"
            read_only  = true
          }
        }

        volume {
          name = "azure-config-file"

          secret {
            secret_name = "${kubernetes_secret_v1.gke_externaldns.metadata[0].name}"
          }
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "prod-node"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }          
        }
      }
    }
  }
}
