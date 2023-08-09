resource "azurerm_kubernetes_cluster" "k8s_cluster" {
  kubernetes_version = "1.27.1"
  name                = "${var.k8s_cluster_name}-aks"
  location            = azurerm_resource_group.rg_name[0].location
  resource_group_name = azurerm_resource_group.rg_name[0].name
  dns_prefix          = "${var.k8s_cluster_name}-k8s"

   tags = {
      environment = "prod"
      avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].spoke_gw_name
    }

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = var.aks_vm_sku
    vnet_subnet_id = azurerm_subnet.private_subnet_2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id
    tags = {
      environment = "prod"
      avx_spoke = aviatrix_spoke_transit_attachment.azure_westus2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].spoke_gw_name
    }
    node_labels = {
      "system-node" = "true"
    }
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
    service_cidr      = var.aks_sevice_cidr
    dns_service_ip    = cidrhost(var.aks_sevice_cidr, 10)
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = var.azure_vm_admin_username
    ssh_key {
      key_data = file(var.ssh_public_key_file)
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "prod_node" {
  name                  = "prod"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s_cluster.id
  vm_size               = var.aks_vm_sku
  node_count            = 2
  max_pods              = 50
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.private_subnet_2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id

  tags = {
    environment = "prod"
  }

  node_labels = {
    "prod-node" = "true"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "dev_node" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s_cluster.id
  vm_size               = "Standard_B2ms"
  node_count            = 1
  max_pods              = 10
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.private_subnet_2[var.azure_spoke_vnets[local.azure_spoke[0].region][0]].id

  tags = {
    environment = "dev"
  }

  node_labels = {
    "dev-node" = "true"
  }

  node_taints = [
    "environment=dev:NoSchedule"
  ]
}

resource "azurerm_role_assignment" "k8s_network_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.k8s_cluster.identity[0].principal_id
}

provider "kubernetes" {
  alias                  = "aks"
  host                   = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.host
  username               = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.username
  password               = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  alias                    = "aks"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.host
    username               = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.username
    password               = azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s_cluster.kube_config.0.cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "aks_certmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider = kubernetes.aks
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "aks_certmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node,
    kubernetes_namespace.aks_certmanager
  ]
  provider   = helm.aks
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

resource "helm_release" "aks_trustmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node,
    kubernetes_namespace.aks_certmanager,
    helm_release.aks_certmanager
  ]
  provider   = helm.aks
  name       = "trust-manager"
  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"
  namespace  = "cert-manager"
  version    = "v0.5.0"
}

resource "kubernetes_secret_v1" "aks_certmanager_ca" {  
  provider = kubernetes.aks
  metadata {
    name      = "ca-clusterissuer"
    namespace = kubernetes_namespace.aks_certmanager.metadata[0].name
  }
  data = {
    "tls.crt" = trimspace(file("ca-chain.pem"))
    "tls.key" = trimspace(file("intermediatekeydecrypted.pem"))
  }
}


resource "helm_release" "nginx_ingress" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider   = helm.aks
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "kube-system"

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = ""
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

resource "kubernetes_namespace" "aks_dev" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider = kubernetes.aks
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "aks_prod" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider = kubernetes.aks
  metadata {
    name = "prod"
  }
}


resource "kubernetes_deployment_v1" "myipapp_deployment" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider = kubernetes.aks
  metadata {
    name = "myipapp-deployment"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
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

resource "kubernetes_deployment_v1" "aks_getcerts" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node,
    null_resource.aks_certmanager
  ]
  provider = kubernetes.aks
  metadata {
    name = "aks-getcerts"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
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

resource "kubernetes_pod_v1" "aks_dev_pod" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.dev_node
  ]

  provider = kubernetes.aks

  metadata {
    name = "dev-pod"
    namespace = kubernetes_namespace.aks_dev.metadata[0].name
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

resource "kubernetes_service" "myipapp_service" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node ,
    kubernetes_deployment_v1.aks_externaldns
  ]
  provider = kubernetes.aks
  metadata {
    name = "aks-myip-svc"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
      "external-dns.alpha.kubernetes.io/hostname" = "aks-myip-svc.${azurerm_private_dns_zone.cse_org.name}"
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
}

resource "kubernetes_service" "aks_getcerts_service" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node,
    kubernetes_deployment_v1.aks_externaldns,
    null_resource.aks_certmanager
  ]
  provider = kubernetes.aks
  metadata {
    name = "aks-getcerts-svc"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
      "external-dns.alpha.kubernetes.io/hostname" = "aks-getcerts-svc.${azurerm_private_dns_zone.cse_org.name}"
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
}

resource "kubernetes_secret_v1" "aks_cacert" {
  provider = kubernetes.aks
  metadata {
    name      = "cacert"
    namespace = "kube-system"
  }
  type = "Opaque"
  data = {
    "cacert.crt" = trimspace(file("ca-chain.pem"))
  }
}

resource "kubernetes_config_map_v1" "aks_load_certs_script" {
  provider = kubernetes.aks
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

resource "kubernetes_daemon_set_v1" "aks_cert_customizations" {
  provider = kubernetes.aks
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
            name         = kubernetes_config_map_v1.aks_load_certs_script.metadata[0].name
            default_mode = "0744"
          }
        }

        volume {
          name = "cacert"

          secret {
            secret_name  = kubernetes_secret_v1.aks_cacert.metadata[0].name
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


resource "null_resource" "aks_credentials" {  
  provisioner "local-exec" {
    command = <<EOF
    az aks get-credentials -n ${azurerm_kubernetes_cluster.k8s_cluster.name} -g ${azurerm_kubernetes_cluster.k8s_cluster.resource_group_name} --admin
    EOF
  }
}

resource "time_sleep" "aks_wait_for_webhook_servers" {
  depends_on = [ 
    null_resource.aks_credentials,
    kubernetes_secret_v1.aks_certmanager_ca,
    helm_release.aks_certmanager,
    helm_release.aks_trustmanager,
    helm_release.nginx_ingress
  ]
  create_duration = "3m"
}

resource "null_resource" "aks_certmanager" {
  depends_on = [ 
    time_sleep.aks_wait_for_webhook_servers
  ]
  provisioner "local-exec" {
    command = <<EOF
    kubectl apply -f certmanager.yaml
    EOF
  }
}


resource "kubernetes_ingress_v1" "myipapp_ingress" {
  depends_on = [ 
    kubernetes_deployment_v1.aks_externaldns,
    null_resource.aks_certmanager    
  ]
  provider = kubernetes.aks
  metadata {
    name = "aks-ingress"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "cert-manager.io/cluster-issuer"             = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    rule {
      host = "aks-ingress.${azurerm_private_dns_zone.cse_org.name}"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.myipapp_service.metadata[0].name
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
              name = kubernetes_service.aks_getcerts_service.metadata[0].name
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
      hosts = ["aks-ingress.${azurerm_private_dns_zone.cse_org.name}"]
      secret_name = kubernetes_secret_v1.aks_certmanager_ca.metadata[0].name
    }
  }
}


# External DNS Configuration

resource "kubernetes_secret_v1" "aks_externaldns" {
  depends_on = [
    azurerm_role_assignment.k8s_dns_contributor,
    azurerm_role_assignment.k8s_rg_reader
  ]
  provider = kubernetes.aks
  metadata {
    name = "k8s-dns"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
  }
  type = "Opaque"
  data = {
    "azure.json" = jsonencode({
      "tenantId"         = "${data.azurerm_subscription.current.tenant_id}"
      "subscriptionId"   = "${data.azurerm_subscription.current.subscription_id}"
      "resourceGroup"    = "${azurerm_resource_group.rg_name[0].name}"
      "aadClientId"      = "${azuread_service_principal.k8s.application_id}"
      "aadClientSecret"  = "${azuread_service_principal_password.k8s_password.value}"
    })
  }
}

resource "kubernetes_cluster_role_v1" "aks_external_dns" {
  provider = kubernetes.aks
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

resource "kubernetes_cluster_role_binding_v1" "aks_external_dns_viewer" {
  provider = kubernetes.aks
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.aks_external_dns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.aks_external_dns.metadata[0].name
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
  }
}

resource "kubernetes_service_account_v1" "aks_external_dns" {
  provider = kubernetes.aks
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
  }
}



resource "kubernetes_deployment_v1" "aks_externaldns" {
  depends_on = [ 
    kubernetes_daemon_set_v1.aks_cert_customizations,
    azurerm_kubernetes_cluster_node_pool.prod_node
  ]
  provider = kubernetes.aks
  metadata {
    name = "externaldns"
    namespace = kubernetes_namespace.aks_prod.metadata[0].name
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
        service_account_name = kubernetes_service_account_v1.aks_external_dns.metadata[0].name
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
            "--txt-prefix=akstxt-"
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
            secret_name = "${kubernetes_secret_v1.aks_externaldns.metadata[0].name}"
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
