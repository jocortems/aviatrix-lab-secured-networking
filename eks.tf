module "eks" {
  count   = length(local.aws_spoke) > 0 ? 1 : 0
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name                   = "eks-${var.k8s_cluster_name}"
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false
  cluster_ip_family              = "ipv4"
  #cluster_service_ipv4_cidr      = var.eks_svc_cidr

  tags = {
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].spoke_gw_name
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  
  vpc_id                   = aws_vpc.aws_vpc[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id
  subnet_ids               = [aws_subnet.eks_node_subnet_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id, aws_subnet.eks_node_subnet_2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
  control_plane_subnet_ids = [aws_subnet.eks_master_subnet_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id, aws_subnet.eks_master_subnet_2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
  cluster_security_group_name = "eks-sg"
  create_cluster_security_group = true
  create_cluster_primary_security_group_tags = true
  create_node_security_group = true
  cluster_security_group_additional_rules = {
  rfc1918_a = {
    description = "Allow all RFC1918-A traffic"
    type        = "ingress"
    protocol    = "all"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["10.0.0.0/8"]
  },
  rfc1918_b = {
    description = "Allow all RFC1918-B traffic"
    type        = "ingress"
    protocol    = "all"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["172.16.0.0/12"]
  },
  rfc1918_c = {
    description = "Allow all RFC1918-C traffic"
    type        = "ingress"
    protocol    = "all"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["192.168.0.0/16"]
  },
  deployer = {
    description = "deployer"
    type        = "ingress"
    protocol    = "all"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = [replace(data.http.my_ip.body, "\n", "/32")]
  }
}


  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  create                    = true
  manage_aws_auth_configmap = true

  self_managed_node_group_defaults = {
    # enable discovery of autoscaling groups by cluster-autoscaler
    autoscaling_group_tags = {
      "k8s.io/cluster-autoscaler/enabled" : true
      "k8s.io/cluster-autoscaler/eks-${var.k8s_cluster_name}" : "owned"
    }
    use_name_prefix = false
    cluster_ip_family = "ipv4"
    key_name = aws_key_pair.aws_key_pair[local.aws_transit[0]["region"]].key_name
    vpc_security_group_ids = [aws_security_group.private_subnet_sg[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
    
    ami_id = data.aws_ami.eks_default.id
    #platform = "ubuntu2004"

    ebs_optimized     = false
    enable_monitoring = false    

    timeouts = {
      create = "80m"
      update = "80m"
      delete = "80m"
    }

    tags = {      
      avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].spoke_gw_name
    }
  }

  self_managed_node_groups = {
    prod_node_group = {
      name            = "prod-node-group"
      subnet_ids = [aws_subnet.eks_node_subnet_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id, aws_subnet.eks_node_subnet_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
      vpc_security_group_ids = [aws_security_group.private_subnet_sg[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=prod-node=true'"
      instance_type = var.eks_vm_sku

      create_iam_role          = true
      iam_role_name            = "eks-prod-node-group"
      iam_role_attach_cni_policy = true
      create_iam_instance_profile = true
      iam_role_use_name_prefix = false
      iam_role_description     = "Self managed prod node group role"

      min_size     = 1
      max_size     = 5
      desired_size = 2
  
      launch_template_name            = "eks-prod-node-group"
      launch_template_use_name_prefix = true
      launch_template_description     = "Prod node group launch template"      

      tags = {
        environment = "prod"
      }
    }
    

    dev_node_group = {
      name            = "dev-node-group"
      subnet_ids = [aws_subnet.eks_node_subnet_1[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id, aws_subnet.eks_node_subnet_2[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
      vpc_security_group_ids = [aws_security_group.private_subnet_sg[var.aws_spoke_vnets[local.aws_spoke[0].region][0]].id]
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=dev-node=true --register-with-taints=taint_environment=dev:NoSchedule'"
      instance_type = "t3.small"

      create_iam_role          = true
      iam_role_name            = "eks-dev-node-group"
      iam_role_attach_cni_policy = true
      create_iam_instance_profile = true
      iam_role_use_name_prefix = false
      iam_role_description     = "Self managed dev node group role"

      min_size     = 1
      max_size     = 5
      desired_size = 1
  
      launch_template_name            = "eks-dev-node-group"
      launch_template_use_name_prefix = true
      launch_template_description     = "Dev node group launch template"
    }

    tags = {
        environment = "dev"
      }
  }
}

provider "kubernetes" {
  host                   = module.eks[0].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks[0].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name]
    }
  }
}

resource "kubernetes_namespace" "eks_certmanager" {
  depends_on = [
    module.eks
  ]
  metadata {
    name = "cert-manager"
  }
}


resource "helm_release" "eks_certmanager" {
  depends_on = [ 
    module.eks,   
    kubernetes_daemon_set_v1.eks_cert_customizations ,
    kubernetes_namespace.eks_certmanager
  ]
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

resource "helm_release" "eks_trustmanager" {
  depends_on = [ 
    kubernetes_daemon_set_v1.eks_cert_customizations,
    module.eks,
    kubernetes_namespace.eks_certmanager,
    helm_release.eks_certmanager
  ]  
  name       = "trust-manager"
  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"
  namespace  = "cert-manager"
  version    = "v0.5.0"
}

resource "kubernetes_secret_v1" "eks_certmanager_ca" {
  metadata {
    name      = "ca-clusterissuer"
    namespace = kubernetes_namespace.eks_certmanager.metadata[0].name
  }
  data = {
    "tls.crt" = trimspace(file("ca-chain.pem"))
    "tls.key" = trimspace(file("intermediatekeydecrypted.pem"))
  }
}

resource "aws_iam_policy" "nlb_controller_policy" {
  name        = "awsLoadBalancerController"
  description = "Policy used for EKS aws-load-balancer-controller"
  policy      = file("awsEksLoadBalancerControllerPolicy.json")
}

module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "load-balancer-controller"
  oidc_providers = {
    main = {
      provider_arn = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  role_policy_arns = {
    policy = aws_iam_policy.nlb_controller_policy.arn
  }
  tags = {
    environment = "production"
  }
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
    }
  }
  automount_service_account_token = true
}


resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [  
    kubernetes_daemon_set_v1.eks_cert_customizations
  ]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks[0].cluster_name
  }

  set {
    name  = "imageTag"
    value = "v2.5.4"
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
  }

  set {
    name  = "logLevel"
    value = "debug"
  }
}

resource "time_sleep" "eks_wait_for_lb_controller_webhooks" {
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
  create_duration = "3m"
}

resource "helm_release" "aws_nginx_ingress" {
  depends_on = [ 
    time_sleep.eks_wait_for_lb_controller_webhooks
  ]
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "kube-system"

  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internal"
  }

  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-healthcheck-path"
    value = "/nginx-health"
  }

  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "nginx-ingress"
  }

  set {
    name = "controller.healthStatus"
    value = true
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
  }
}

resource "kubernetes_namespace" "eks_dev" {
  depends_on = [  
    module.eks
  ]
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "eks_prod" {
  depends_on = [  
    module.eks
  ]
  metadata {
    name = "prod"
  }
}

resource "kubernetes_deployment_v1" "aws_myipapp_deployment" {  
  depends_on = [ 
    module.eks,   
    kubernetes_daemon_set_v1.eks_cert_customizations 
  ]
  metadata {
    name = "myipapp-deployment"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
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
          image = "jorgecortesdocker/myipapp:v3"

          port {
            container_port = 8080
          }
        }
        affinity {          
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

resource "kubernetes_deployment_v1" "eks_getcerts" {
  depends_on = [ 
    kubernetes_daemon_set_v1.eks_cert_customizations,
    module.eks,
    null_resource.eks_certmanager
  ]
  metadata {
    name = "eks-getcerts"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
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



resource "kubernetes_service" "aws_myipapp_service" {  
  depends_on = [ 
    helm_release.aws_load_balancer_controller,
    kubernetes_deployment_v1.eks_externaldns,
    null_resource.eks_certmanager
  ]

  lifecycle {
    ignore_changes = [
      spec[0].load_balancer_class
    ]
  }
  metadata {
    name = "eks-myip-svc"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/api/healthcheck"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port" = "8080"
      "service.beta.kubernetes.io/aws-load-balancer-name" = "myipap-svc"
      "external-dns.alpha.kubernetes.io/hostname" = "eks-myip-svc.${azurerm_private_dns_zone.cse_org.name}"
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

resource "kubernetes_service" "eks_getcerts_service" {
  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_deployment_v1.eks_externaldns,
    null_resource.eks_certmanager
  ]
  lifecycle {
    ignore_changes = [
      spec[0].load_balancer_class
    ]
  }
  metadata {
    name = "eks-getcerts-svc"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/api/healthcheck"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port" = "5000"
      "service.beta.kubernetes.io/aws-load-balancer-name" = "getcerts-svc"
      "external-dns.alpha.kubernetes.io/hostname" = "eks-getcerts-svc.${azurerm_private_dns_zone.cse_org.name}"
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

resource "kubernetes_pod_v1" "eks_dev_pod" {
  depends_on = [ 
    kubernetes_daemon_set_v1.eks_cert_customizations,
    module.eks
  ]
  metadata {
    name = "dev-pod"
    namespace = kubernetes_namespace.eks_dev.metadata[0].name
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


resource "kubernetes_secret_v1" "eks_cacert" {
  depends_on = [ 
    module.eks
  ]
  metadata {
    name      = "cacert"
    namespace = "kube-system"
  }
  type = "Opaque"
  data = {
    "cacert.crt" = trimspace(file("ca-chain.pem"))
  }
}

resource "kubernetes_config_map_v1" "eks_load_certs_script" {
  depends_on = [ 
    module.eks
  ]
  metadata {
    name      = "load-certs-script"
    namespace = "kube-system"
  }

  data = {
    "load-certs.sh" = <<EOF
#!/usr/bin/env bash
set -x

echo "Copying the custom root certificate"
cp /cacert/cacert.crt /mnt/etc/pki/ca-trust/source/anchors/cacert.crt
echo "Certificates copied"
nsenter --target 1 --mount update-ca-trust
nsenter --target 1 --mount bash -c "systemctl is-active --quiet containerd && echo 'Restarting containerd' && systemctl restart containerd"
EOF
  }
}

resource "kubernetes_daemon_set_v1" "eks_cert_customizations" {
  depends_on = [ 
    module.eks
  ]
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
          image = "ecpe4s/ubuntu20.04-runner-x86_64:2023.06.01"

          command = ["/scripts/load-certs.sh"]

          volume_mount {
            name       = "etc"
            mount_path = "/mnt/etc"
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
          name = "etc"

          host_path {
            path = "/etc"
          }
        }

        volume {
          name = "scripts"

          config_map {
            name         = kubernetes_config_map_v1.eks_load_certs_script.metadata[0].name
            default_mode = "0744"
          }
        }

        volume {
          name = "cacert"

          secret {
            secret_name  = kubernetes_secret_v1.eks_cacert.metadata[0].name
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

resource "null_resource" "eks_credentials" {
  depends_on = [ 
    null_resource.gke_credentials,
    null_resource.gke_certmanager,
    module.eks
    ]
  provisioner "local-exec" {
    command = <<EOF
    aws eks update-kubeconfig --name ${module.eks[0].cluster_name}
    EOF
  }
}

resource "time_sleep" "eks_wait_for_webhook_servers" {
  depends_on = [ 
    null_resource.eks_credentials,
    kubernetes_secret_v1.eks_certmanager_ca,
    helm_release.eks_certmanager,
    helm_release.eks_trustmanager,
    helm_release.aws_nginx_ingress
  ]
  create_duration = "3m"
}

resource "null_resource" "eks_certmanager" {
  depends_on = [ 
    time_sleep.eks_wait_for_webhook_servers
  ]
  provisioner "local-exec" {
    command = <<EOF
    kubectl apply -f certmanager.yaml
    EOF
  }
}

resource "kubernetes_ingress_v1" "eks_myipapp_ingress" {  
  depends_on = [ 
    null_resource.eks_certmanager,
    kubernetes_deployment_v1.eks_externaldns
  ]
  metadata {
    name = "eks-ingress"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "cert-manager.io/cluster-issuer"             = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    rule {
      host = "eks-ingress.${azurerm_private_dns_zone.cse_org.name}"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.aws_myipapp_service.metadata[0].name
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
              name = kubernetes_service.eks_getcerts_service.metadata[0].name
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
      hosts = ["eks-ingress.${azurerm_private_dns_zone.cse_org.name}"]
      secret_name = kubernetes_secret_v1.aks_certmanager_ca.metadata[0].name
    }
  }
}

# External DNS Configuration

resource "kubernetes_secret_v1" "eks_externaldns" {
  depends_on = [
    azurerm_role_assignment.k8s_dns_contributor,
    azurerm_role_assignment.k8s_rg_reader
  ]
  metadata {
    name = "k8s-dns"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
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

resource "kubernetes_cluster_role_v1" "eks_external_dns" {
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

resource "kubernetes_cluster_role_binding_v1" "eks_external_dns_viewer" {
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.eks_external_dns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.eks_external_dns.metadata[0].name
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
  }
}

resource "kubernetes_service_account_v1" "eks_external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
  }
}



resource "kubernetes_deployment_v1" "eks_externaldns" {
  depends_on = [ 
    kubernetes_daemon_set_v1.eks_cert_customizations,
    module.eks
  ]
  metadata {
    name = "externaldns"
    namespace = kubernetes_namespace.eks_prod.metadata[0].name
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
        service_account_name = kubernetes_service_account_v1.eks_external_dns.metadata[0].name
        container {
          image = "registry.k8s.io/external-dns/external-dns:v0.13.5"
          name  = "externaldns"
          
          args = [
            "--source=service",
            "--source=ingress",
            "--aws-prefer-cname",
            "--domain-filter=${azurerm_private_dns_zone.cse_org.name}",
            "--provider=azure-private-dns",
            "--azure-resource-group=${azurerm_resource_group.rg_name[0].name}",
            "--azure-subscription-id=${data.azurerm_subscription.current.subscription_id}",
            "--txt-prefix=ekstxt-"
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
            secret_name = "${kubernetes_secret_v1.eks_externaldns.metadata[0].name}"
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
