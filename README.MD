# Aviatrix Lab for Testing Secured Networking Features

## Overview

This code deploys infrastructure across Azure, AWS and GCP to facilitate testing Aviatrix Secured Networking feature set at scale. I tried to strike a balance between providing flexibility in configuration parameters and avoiding the paradox of choice; as such some parameters are hardcoded and some can be specified as variables. I made some basic testing to make sure the code works as intended; however it is likely that I missed some things and you might encounter errors with some variable combinations; if you do so please don't hesitate in letting me know, or better yet, submitting a pull request; I'll be more than happy to merge it into this code!

## Description

This code deploys the following artifacts:

1. At least 4 VNETs in Azure as follows.:
 - One VNET is an Aviatrix Transit VNET. Additional Transit VNETs can be created by adding more objects to the set `var.azure_transit_vnets`. Only one Transit VNET per region is supported in this code
 - One VNET is used to simulate on premises. It deploys an NVA using StrongSwan and, if `bgp` is chosen for `var.s2c_routing`, BIRD routing daemon is used for BGP. It also deploys a client VM in this VNET for testing. This Client VM has a public IP address associated with it for direct Internet access
 - One Aviatrix Spoke VNET hosting workloads. This VNET will have 5 VMs across 3 subnets and one AKS cluster with 2 node pools in their own private subnet, prod node-pool has 2 nodes tagged with `environment=prod` and dev node-pool has 1 node tagged with `environment=dev`. One of the VMs is named `jumpboxVM` with a public IP address associated to it for direct internet access, the other 4 VMs are deployed to two private subnets, and the VMs are tagged with `environment=prod` and `environment=dev`; this is to showcase intra-subnet level segmentation. Additional spoke VNETs can be created by adding more CIDRs to the list in the region, or by adding another region with a list of CIDRs to the set `var.azure_spoke_vnets`, each of these VNETs will only have 4 VMs across 2 different subnets. The spoke VNETs are automatically connected to the transit VNET in the same region. **Make sure the provided CIDRs are /16, other CIDR lengths might yield errors**
 - One Aviatrix Site2Cloud Spoke Landing VNET. This VNET terminates the OnPremises NVA VPN tunnel, there are three possible configurations depending on the values of `var.s2c_routing` and `var.s2c_nat`:
  - **Static routing with custom SNAT and DNAT**: The S2C VPN is terminated on Aviatrix standalone gateways using Single IP HA. Traffic can only be initiated from OnPremises VM client towards the workloads in the cloud. The OnPrem VM is SNAT'ed to hardcoded IP address `100.127.255.100`, and DNAT rules are hardcoded and created as follows:

   | Virtual IP | Real IP |
   |------------|---------|
   | 100.64.10.4/32 | IP address of VM ending in 10.11 in the first Azure Spoke VNET created |
   | 100.64.10.5/32 | IP address of VM ending in 10.21 in the first Azure Spoke VNET created |
   | 100.64.100.1/32 | IP address of AKS load-balancer service aks-myip-svc. It is accessed on port :8080/api/ip |
   | 100.64.100.3/32 | IP address of AKS load-balancer service aks-getcerts-svc. It is accessed on port :5000/api/tls?host=ANY_FQDN |
   | 100.64.100.2/32 | IP address of AKS ingress aks-ingress. Can only be acccessed using host headers matching the DNS entry created in Azure Private DNS Zone, using either HTTPS or HTTP on paths /api/ip and /api/tls?host=ANY_FQDN. Example `curl --resolve aks-ingress.aviatrix.internal:443:100.64.100.2 https://aks-ingress.aviatrix.internal/api/tls?host=aviatrix.com` |
   | 100.64.110.1/32 | IP address of GKE load-balancer service gke-myip-svc. It is accessed on port :8080/api/ip |
   | 100.64.110.3/32 | IP address of GKE load-balancer service gke-getcerts-svc. It is accessed on port :5000/api/tls?host=ANY_FQDN |
   | 100.64.110.2/32 | IP address of GKE ingress gke-ingress. Can only be acccessed using host headers matching the DNS entry created in Azure Private DNS Zone, using either HTTPS or HTTP on paths /api/ip and /api/tls?host=ANY_FQDN. Example `curl --resolve aks-ingress.aviatrix.internal:443:100.64.100.2 https://aks-ingress.aviatrix.internal/api/ip` |

  - **Static routing with Mapped NAT**: The S2C VPN is terminated on Aviatrix standalone gateways using Single IP HA. Traffic can be initiated either from OnPremises VM or cloud VMs. The mapping is hardcoded and defined as below. As you can see from the mappings, it is assumed that the OnPrem VNET has the same CIDR as the first VNET in Azure, thus only traffic destined to or coming from that CIDR is NAT'ed. **Because `var.azure_spoke_vnets` is a set, VNETs are ordered lexichographically based on their region i.e if you define VNETs in `West US 2` and `East US 2`, the first VNET will be the first VNET in the list for `East US 2`, regardless of the order you define in the variable**
  
  ```
  remote_source_real_cidrs          = [ OnPremises VNET CIDR ]
  remote_source_virtual_cidrs       = ["100.127.0.0/16"]
  remote_destination_real_cidrs     = [ all of the Spoke VNET CIDRs across all clouds in order Azure, AWS and GCP ]
  remote_destination_virtual_cidrs  = [ "100.64.0.0/16" + all of the Spoke VNET CIDRs across all clouds in order Azure, AWS and GCP, except for the first Azure spoke VNET which is assumed to overlap with OnPrem ]
  local_source_real_cidrs           = [ all of the Spoke VNET CIDRs across all clouds in order Azure, AWS and GCP ]
  local_source_virtual_cidrs        = [ "100.64.0.0/16" + all of the Spoke VNET CIDRs across all clouds in order Azure, AWS and GCP, except for the first Azure spoke VNET which is assumed to overlap with OnPrem ]
  local_destination_real_cidrs      = [ OnPremises VNET CIDR ]
  local_destination_virtual_cidrs   = ["100.127.0.0/16"]
  ```

  - **BGP routing with custom SNAT and DNAT**: The S2C VPN is terminated on Aviatrix Spoke gateways of the landing VNET. Traffic can only be initiated from OnPremises VM client towards the workloads in the cloud. The OnPrem VM is SNAT'ed to IP address `100.127.255.100` on the primary spoke gateway and `100.127.255.101` on the spoke HA gateway to maintain traffic symmetry. DNAT rules are the same as for scenario *Static routing with custom SNAT and DNAT*.

2. At least two VPCs in AWS as follows:
 - One VPC is an Aviatrix Transit VPCs. No additional Aviatrix Transit VPCs can be specified for AWS because each region requires its own AWS Terraform provider, and this code only supports one Aviatrix Transit VPC per region
 - One Aviatrix Spoke VPC hosting workloads. This VPC will have 4 EC2 instances across 2 private subnets and one EKS cluster with 2 self-managed node pools in their own private subnet, prod node-pool has 2 nodes tagged with `environment=prod` and dev node-pool has 1 node tagged with `environment=dev`; this is to showcase intra-subnet segmentation. The EC2 instances are tagged with `environment=prod` and `environment=dev`; this is to showcase intra-subnet level segmentation. Additional spoke VPCs can be created by adding more CIDRs to the list in the region. Additional VPCs will only have 4 EC2 instances across 2 different subnets, no EKS clusters will be deployed for these additional VPCs. Adding multiple regions is not supported by this code because each region requires its own AWS Terraform provider. **Make sure the provided CIDRs are /16, other CIDR lengths might yield errors**

3. At least two VPCs in GCP as follows:
 - One VPC is an Aviatrix Transit VPCs. Additional Transit VPCs can be created by adding more objects to the set `var.gcp_transit_vnets`. Only one Transit VPC per region is supported in this code
 - One Aviatrix Spoke VPC hosting workloads. This VPC will only have one GKE standard cluster with 2 node pools in their own private subnet, prod node-pool has 2 nodes tagged with `environment=prod` and dev node-pool has 1 nodes tagged with `environment=dev`. Additional spoke VPCs can be created by adding more CIDRs to the list in the region, or by adding another region with a list of CIDRs to the set `var.gcp_spoke_vnets`; additional VPCs will only have 4 compute instances across 2 different subnets, these instances will be labeled with `environment=prod` and `environment=dev`, no GKE clusters will be deployed for these additional VPCs. The spoke VNETs are automatically connected to the transit VNET in the same region. **Make sure the provided CIDRs are /16, other CIDR lengths might yield errors**

4. One Azure DNS Private Zone. Records for all VMs, EC2 instances, GCP compute instances as well as the different kubernetes services and ingress resources deployed are automatically created in this zone and can be accessed by name from Azure VMs and AWS EC2 Instances, but not from GCP compute instances because GCP only allows reachability of DNS forwarding targets over CloudVPN and Cloud Interconnect
5. One Azure AD Application assigned the `Reader` role for the Resource Group created as part of this code and `Private DNS Zone Contributor` for the Azure DNS Private Zone created as part of this code. This is used to allow Kubernetes ExternalDNS automatically create DNS records for services and ingress resources deployed to the AKS, EKS and GKE clusters
6. One Azure DNS Private Resolver with an Inbound Endpoint used as the DNS forwarding target for AWS and GCP
7. One AWS Route53 Outbound Resolver Endpoint that forwards all queries for the domain specified in `var.internal_dns_zone` to Azure DNS Private Resolver Inbound Endpoint
8. One GCP DNS Forwarding Zone to forward all queries for the domain specified in `var.internal_dns_zone` to Azure DNS Private Resolver Inbound Endpoint. Note however that this doesn't work because GCP doesn't allow reachability of DNS forwarding targets over NVAs (Aviatrix Spoke Gateways). Only the first VPC is linked to this DNS forwarding zone
9. If multiple GCP Spoke VPCs are created, a GCP DNS Peering Zone is created and additional VPCs are linked to this peering zone, this peering zone is peered to the GCP DNS Forwarding Zone created in (8) above
10. One AKS cluster with two node pools in the same private subnet. There are two services of `kind: loadBalancer` deployed to the cluster, `aks-myip-svc:8080/api/ip` and `aks-getcerts-svc:5000/api/tls?host=ANY_FQDN`, these services can be accessed using their IP address or the DNS entry created in Azure Private DNS Zone from instances in Azure and AWS. There is also an ingress resource `aks-ingress` exposing the same services over HTTP and HTTPS; the only way to access the ingress resource is through its FQDN. Because DNS resolution doesn't work from instances in GCP you can do `curl --resolve aks-ingress.aviatrix.internal:443:10.12.11.61 https://aks-ingress.aviatrix.internal/api/ip`
11. One EKS cluster with two self-managed node pools in the same private subnet. There are two services of `kind: loadBalancer` deployed to the cluster, `eks-myip-svc:8080/api/ip` and `eks-getcerts-svc:5000/api/tls?host=ANY_FQDN`, these services can be accessed using their IP address or the DNS entry created in Azure Private DNS Zone from instances in Azure and AWS. There is also an ingress resource `eks-ingress` exposing the same services over HTTP and HTTPS; the only way to access the ingress resource is through its FQDN. Because DNS resolution doesn't work from instances in GCP you can do `curl --resolve eks-ingress.aviatrix.internal:443:10.20.11.61 https://eks-ingress.aviatrix.internal/api/tls?host=aviatrix.com`
12. One GKE standard cluster with two node pools in the same private subnet. There are two services of `kind: loadBalancer` deployed to the cluster, `gke-myip-svc:8080/api/ip` and `gke-getcerts-svc:5000/api/tls?host=ANY_FQDN`, these services can be accessed using their IP address or the DNS entry created in Azure Private DNS Zone from instances in Azure and AWS. There is also an ingress resource `gke-ingress` exposing the same services over HTTP and HTTPS; the only way to access the ingress resource is through its FQDN. Because DNS resolution doesn't work from instances in GCP you can do `curl --resolve gke-ingress.aviatrix.internal:443:10.33.16.8 https://gke-ingress.aviatrix.internal/api/ip`
13. Aviatrix Transit FireNet can be optionally enabled on the Transit Gateways and, if enabled, the firewalls will be created and associated using Aviatrix `mc-firenet` Terraform module. Note however that configuring the firewalls needs to be done manually. In order to enable FireNet you can define transit_vnets variable as follows:
```
azure_transit_vnets = {
    "West US 2" = {
        "cidr" = "10.19.0.0/16",
        "asn" = 64510,
        "gw_size" = "Standard_D8_v5",
        "firenet" =  true,
        "fw_image" = "Palo Alto Networks VM-Series Next-Generation Firewall (BYOL)",
        "hpe"     = false,
        "bgpol"   = true,
        "bgpol_int" = 1
    }
}
```
14. Aviatrix BGPoLAN on the transit gateways can be enabled for Azure and GCP. An example to enable on GCP is as follows:
```
gcp_transit_vnets = {
    "us-west1" = {
        "cidr" =  "10.39.0.0/16",
        "asn" = 64530,
        "gw_size" = "n1-standard-4",
        "firenet" = true,
        "fw_image" = "Palo Alto Networks VM-Series Next-Generation Firewall BYOL",
        "firenet_mgmt_cidr" = "10.38.255.224/29",
        "firenet_egress_cidr" = "10.38.255.232/29",
        "lan_cidr" = "10.38.255.0/26",
        "hpe"     = false,
        "bgpol"   = true,
        "bgpol_int" = [{
            "subnet" = "10.38.255.240/29"
        }]
        "ha_bgpol_int" = [{
            "subnet" = "10.38.255.248/29"
        }]
    }
}
```
15. Aviatrix Distributed Cloud Firewall is enabled; smart groups using CSP tags and CIDRs for OnPrem network and the kubernetes clusters are pre-created, but no rules are created
16. A custom rootCA certificate and its corresponding private key is uploaded to Aviatrix CoPilot to facilitate testing TLS decryption functionality. All compute instances as well as the Kubernetes worker nodes are bootstrapped to add this custom rootCA to the Trusted Root Certificate Store. If you want to use your own rootCA or the rootCA certificate downloaded from CoPilot you can replace the contents of files `ca-chain.pem` and `intermediatekeydecrypted.pem`; you will also need to edit the contents of file `cloud-init.sh` to make sure compute instances deployed trust your rootCA
17. All compute instances deployed to private subnets, along with the Kubernetes worker nodes, egress through Aviatrix Spoke Gateways
18. All compute instances deployed are running two services that can be accessed with cURL, one on port 80 and another on port 8080/api/ip
19. It is possible to SSH into all of the instances, including the kubernetes worker nodes, using the SSH private key corresponding to the SSH public key passed in `var.ssh_public_key_file`. The username for Azure and GCP instances is defined in `var.azure_vm_admin_username` and defaults to `avxuser`. The username for AWS EC2 instances is `ubuntu`, and for EKS worker nodes is `ec2-user`

## How to run this code

### Prerequisites

1. [Terraform v1.3+](https://www.terraform.io/downloads.html)
2. [Azure CLI v2.51](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
3. [Gcloud CLI](https://cloud.google.com/sdk/docs/install)
4. [AWS CLI v2.11](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). Make sure to set the AWS CLI credentials to use the same credentials as the Terraform AWS provider and the account has been assigned the policies as described in (8) below. Make sure ~/.aws/config file specifies the same region as the AWS terraform provider. [EKS module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) relies on AWS CLI to add the self-managed worker nodes to the cluster. Before running this code run `aws sts get-caller-identity` to make sure AWS CLI is using the proper user
5. [kubectl v1.27](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
6. [gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin)
7. The GCP Service Account used to run this code must have the following roles:
 - Compute Admin
 - DNS Administrator
 - DNS Peer
 - Kubernetes Engine Admin
 - Kubernetes Engine Cluster Admin
 - Service Account user
8. The AWS IAM role assumed by Terraform IAM user must have the following permissions to successfully create the EKS cluster; even if it has AdministratorAccess Policy attached to it:
 - AmazonEKS_CNI_Policy
 - AmazonEKSClusterPolicy
 - AmazonEKSServicePolicy
 - AmazonEKSVPCResourceController
 - AmazonEKSWorkerNodePolicy
9. Aviatrix Controller and CoPilot are deployed and running version 7.1
9. Azure, AWS and GCP accounts onboarded on the Aviatrix Controller
10. Security Group Management and CoPilot Security Group Management are enabled

### Execution

1. Clone this repository `git clone https://github.com/jocortems/aviatrix-lab-secured-networking.git`
2. Configure the providers in `providers.tf`
3. Provide the required variables:

| Name | Description |
|------|---------|
| `ssh_public_key_file` | The corresponding private key will be used to SSH into all of the VMs created, including AKS, GKE and EKS worker nodes. Password authentication is disabled. Make sure this file is in the same folder where you run this code from |
| `azure_account` | Name of the Azure account onboarded on the Aviatrix Controller |
| `aws_account` | Name of the AWS account onboarded on the Aviatrix Controller |
| `gcp_account` | Name of the GCP account onboarded on the Aviatrix Controller |

4. Authenticate to Azure `az login --use-device-code`
5. Export environment variable `USE_GKE_GCLOUD_AUTH_PLUGIN=True`
6. Authenticate to Google Cloud using gcloud cli `gcloud auth application-default login`. This is needed to allow Terraform to deploy Kubernetes resources to GKE
7. Run the Terraform code with `terraform init` `terraform plan` and `terraform apply`
8. It is very likely that the initial apply will fail because of rate limiting on the EKS API Server, if this happens just run `terraform apply` again
9. After tearing down the environment with `terraform destroy` make sure to remove the added AKS, EKS and GKE Kubernetes clusters from your local `~/.kube/config` file. If the clusters are not removed from the file and the code is run again it will fail because it won't be able to update the file with the cluster's information
10. It is very likely that `terraform destroy` won't be able to destroy some of the kubernetes objects and, in turn, unable to destroy the node pools and clusters. If this happens run `terraform state list | grep ^kubernetes | xargs -I {} terraform state rm {}` after `terraform destroy` errors out, go to the AWS console and manually delete the 3 NLBs created by Kubernetes `aws-load-balancer-controller`named `nginx-ingress`, `myipap-svc` and `getcerts-svc`, and then run `terraform destroy` again

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) | ~> 3.64 |
| <a name="provider_azuread"></a> [azuread](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs) | ~> 2.41 |
| <a name="provider_google"></a> [google](https://registry.terraform.io/providers/hashicorp/google/latest/docs) | ~> 4.66 |
| <a name="provider_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | ~> 5.0.0 |
| <a name="provider_aviatrix"></a> [aviatrix](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs) | ~> 3.1 |
| <a name="provider_kubernetes"></a> [kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) | ~> 2.20 |
| <a name="provider_helm"></a> [helm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs) | ~> 2.9 |
| <a name="provider_http"></a> [http](https://registry.terraform.io/providers/hashicorp/http/latest/docs) | ~> 3.2 |

## Variables

| Variable Name | Required | Default Value | Description |
|---------------|----------|---------------|-------------|
| resource_group_name | No | "avxdcftest-rg" |  All resources deployed to Azure will be created under this Resource Group |
| my_ipaddress | No | null | IP address to allow SSH access to the jumpbox VM and OnPrem VM deployed in Azure. If you run this code from your laptop you can leave this field empty, the IP address of your computer will be retrieved by terraform |
| azure_spoke_vnets | No | {"West US 2" =  ["10.10.0.0/16"]} | One spoke VNET will be created for every object in the map. The key of the map is the region where the spoke VNET will be created. The value of the map is a list of CIDR blocks for the spoke VNETs in the region. Multiple regions can be specified. At least one VNET in Azure is needed. Must be /16 |
| azure_transit_vnets | No | {"West US 2" = {"cidr" = "10.19.0.0/16","asn" = 64510,"gw_size" = "Standard_D8_v5"}} | One transit VNET will be created for every object in the map. The key of the map is the region where the transit VNET will be created. The value of the map is some of the attributes for mc-transit module. At least one VNET in Azure is needed. Only one transit per region is supported by this code, but multiple regions can be specified. The transit object passed accepts the following arguments, `cidr (required)`,  `asn (required)`, `gw_size (required)`, `firenet (optional, defaults to false)`, `hpe (optional, defaults to false)`, `bgpol (optional, defaults to false)`, `bgpol_int (must be provided if bgpol is set to true, number of BGPoLAN interfaces)`, `fw_image (must be provided if firenet is set to true)`, `firewall_username (must be provided if firenet is set to true)`, `firewall_password (must be provided if firenet is set to true)` |
| aws_spoke_vnets | No | {"us-west-2" = ["10.20.0.0/16"]} | One spoke VPC will be created for every object in the map. The key of the map is the region where the VPC will be created, the list of CIDRs is the CIDR used for every VPC. At least one VPC in AWS is needed. Only one region is supported by this code because AWS requires one Terraform provider per region. Must be /16 |
| aws_transit_vnets | No | {"us-west-2" = {"cidr" = "10.29.0.0/16","asn" = 64520,"gw_size" = "c5.xlarge"}} | One transit VPC will be created for every object in the map. The value of the map is some of the attributes for mc-transit module. At least one VPC in AWS is needed. Only one region is supported by this code because AWS requires one Terraform provider per region. The transit object passed accepts the following arguments, `cidr (required)`, `asn (required)`, `gw_size (required)`, `firenet (optional, defaults to false)`, `hpe (optional, defaults to false)`, `fw_image (must be provided if firenet is set to true)` |
| gcp_spoke_vnets | No | {"us-west1" = ["10.30.0.0/16","10.31.0.0/16"]} | One spoke VPC will be created for every object in the map. The key of the map is the region where the VPC will be created, the list of CIDRs is the CIDR used for every VPC. At least one VPC in GCP is needed. If only one VPC is created, only the GKE worker nodes will be created but no instances will be created. Instances are only created starting from the second VPC in the list. Additional regions can be specified. Must be /16 |
| gcp_transit_vnets | No | {"us-west1" = {"cidr" =  "10.39.0.0/16","asn" = 64530,"gw_size" = "n1-standard-4"}} | One transit VPC will be created for every object in the map. The value of the map is some of the attributes for mc-transit module. At least one VPC in GCP is needed. This code only supports one transit per region. Multiple regions can be specified. The transit object passed accepts the following arguments, `cidr (required)`,  `asn (required)`, `gw_size (required)`, `firenet (optional, defaults to false)`, `hpe (optional, defaults to false)`, `bgpol (optional, defaults to false)`, `bgpol_int (must be provided if bgpol is set to true, list of BGPoLAN interfaces)`, `fw_image (must be provided if firenet is set to true)`, `firenet_mgmt_cidr (must be provided if firenet is set to true)`, `firenet_egress_cidr (must be provided if firenet is set to true)` |
| azure_vmSKU | No | "Standard_B2ms" | SKU for the VMs in Azure for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete |
| aws_vmSKU | No | "t3.small" | SKU for the VMs in AWS for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete |
| gcp_vmSKU | No | "e2-standard-2" | SKU for the VMs in GCP for testing connectivity. Because of the bootstrapping script, avoid using smaller SKU than this, otherwise provisioning won't complete |
| azure_spoke_gw_sku | No | "Standard_D2_v5" | Size of the Aviatrix Spoke Gateways created in Azure |
| aws_spoke_gw_sku | No | "t3.medium" | Size of the Aviatrix Spoke Gateways created in AWS |
| gcp_spoke_gw_sku | No | "n1-standard-2" | Size of the Aviatrix Spoke Gateways created in GCP |
| azure_vm_admin_username | No | "avxuser" | This is the username used to SSH into the compute instances created in Azure and GCP, including worker nodes for AKS and GKE. The username to SSH into AWS EC2 instances is `ubuntu` and the username to SSH into EKS worker nodes is `ec2-user` |
| ssh_public_key_file | Yes |  | This is the path to the SSH public key file used to SSH into all of the VMs deployed across all clouds, including AKS, GKE and EKS worker nodes |
| azure_account | Yes |  | Existing account on Aviatrix Controller for Azure deployments |
| aws_account | Yes |  | Existing account on Aviatrix Controller for AWS deployments |
| gcp_account | Yes |  | Existing account on Aviatrix Controller for GCP deployments |
| k8s_cluster_name | No | "k8s-cluster" | Suffix used to create the K8S managed clusters in the different clouds. They will be prepended the CSP K8S 3 letter code (aks, eks, gke) |
| aks_sevice_cidr | No | "172.16.255.0/24" | CIDR range used for AKS services |
| aks_vm_sku | No | "Standard_D2_v5" | SKU for the AKS worker nodes in the prod nodepool. Using SKUs smaller than this or BS instances will cause the pods to crash because of the services deployed to the cluster |
| eks_vm_sku | No | "t3.large" | SKU for the EKS worker nodes in the prod nodepool. Using SKUs smaller than this will cause the pods to crash because of the services deployed to the cluster |
| gke_vm_sku | No | "n2-standard-2" | SKU for the GKE worker nodes in the prod nodepool. Using SKUs smaller than this will cause the pods to crash because of the services deployed to the cluster |
| gke_pod_cidr | No | "172.16.0.0/14" | CIDR used for the pods in GKE |
| gke_svc_cidr | No | "172.21.0.0/19" | CIDR used for the services in GKE |
| on_prem_cidr | No | null | If not set, the OnPrem VNET will have the same CIDR as the first VNET computed under var.azure_spoke_vnets. The idea is to showcase overlapping CIDRs and NAT with Site2Cloud |
| s2c_spoke_cidr | No | "10.15.0.0/16" | CIDR used for the spoke VNET in Azure where S2C is terminated |
| s2c_nat | No | "custom" | Type of NAT configured for S2C. If s2c_routing is set to BGP this variable is ignored, only custom NAT is supported with BGP |
| s2c_routing | No | "static" | Type of routing configured for S2C, can be `bgp` or `static` |
| s2c_avx_bgp_asn | No | 64900 | BGP ASN used for the Aviatrix spoke gateway in Azure that terminates the S2C tunnel |
| s2c_onprem_bgp_asn | No | 64800 | BGP ASN used for the on-premises NVA that terminates the S2C tunnel |
| s2c_tunnel_cidr | No | "169.254.255.248/29" | The CIDR block for the tunnel interface. /29 is required because two tunnels are needed |
| internal_dns_zone | No | "aviatrix.internal" | Name of the Azure Private DNS Zone that will be created. Records for all deployments will be added in this zone |


## Functional Examples

These are just some examples of what can be tested with the resources deployed by this code. The idea is to have a large-scale test bed and let your imagination run wild.

From the OnPrem VM, you can access the workloads on the overlapping VNET in Azure as follows. Notice the application running on port 8080/api/ip will return the client IP address as seen by the server, which confirms NAT is taking place:

```
jcortes@onpremVM:~$ hostname -I
10.10.0.10 172.17.0.1 192.168.20.1 
jcortes@onpremVM:~$ curl 100.64.10.4

        ***Welcome to 10.10.10.11 172.17.0.1 192.168.33.1 on port 80***

jcortes@onpremVM:~$ curl 100.64.10.4:8080/api/ip
{
  "my_default_gateway": "192.168.33.1", 
  "my_dns_servers": "['127.0.0.11']", 
  "my_private_ip": "192.168.33.2", 
  "my_public_ip": "20.14.48.40", 
  "path_accessed": "100.64.10.4:8080/api/ip", 
  "x-forwarded-for": null, 
  "your_address": "100.127.255.100", 
  "your_browser": "None", 
  "your_platform": "None"
}
```

It is possible to access workloads in non-overlapping VNETs using the DNS entry created in Azure DNS Private Zone:

```
jcortes@onpremVM:~$ nslookup eks-ingress.aviatrix.internal
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
eks-ingress.aviatrix.internal   canonical name = internal-a54054ce39bc24e94bf5bdce0fcc0c27-603014446.us-west-2.elb.amazonaws.com.
Name:   internal-a54054ce39bc24e94bf5bdce0fcc0c27-603014446.us-west-2.elb.amazonaws.com
Address: 10.20.20.153

jcortes@onpremVM:~$ curl https://eks-ingress.aviatrix.internal/api/ip
{
  "my_default_gateway": "169.254.1.1", 
  "my_dns_servers": "['172.20.0.10']", 
  "my_private_ip": "10.20.21.222", 
  "my_public_ip": "52.12.127.168", 
  "path_accessed": "eks-ingress.aviatrix.internal/api/ip", 
  "x-forwarded-for": "10.20.20.153", 
  "your_address": "10.20.20.75", 
  "your_browser": "None", 
  "your_platform": "None"
}
```

Connect to one of the VMs in the private subnets and inspect the certificates of site `https://aviatrix.com`:

```
avxuser@az-dev1-10:~$ curl -v -I https://aviatrix.com
*   Trying 141.193.213.20:443...
* TCP_NODELAY set
* Connected to aviatrix.com (141.193.213.20) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use h2
* Server certificate:
*  subject: C=US; ST=California; L=San Francisco; O=Cloudflare, Inc.; CN=aviatrix.com
*  start date: Jun 16 00:00:00 2023 GMT
*  expire date: Jun 14 23:59:59 2024 GMT
*  subjectAltName: host "aviatrix.com" matched cert's "aviatrix.com"
*  issuer: C=US; O=Cloudflare, Inc.; CN=Cloudflare Inc ECC CA-3
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55afa99268d0)
> HEAD / HTTP/2
> Host: aviatrix.com
> user-agent: curl/7.68.0
> accept: */*
> 
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* Connection state changed (MAX_CONCURRENT_STREAMS == 256)!
< HTTP/2 200 
HTTP/2 200 
```

Notice the issuer `issuer: C=US; O=Cloudflare, Inc.; CN=Cloudflare Inc ECC CA-3`

Now create a rule to perform TLS decryption for traffic destined to the default `Any-Web` web-group on TCP port 443 and make sure to enable `TLS Decryption` and `Intrusion Detection (IDS)` from the SmartGroup where the VM is in as source. Verify the site certificate again and inspect the issuer.

```
avxuser@az-dev1-10:~$ curl -v -I https://aviatrix.com
*   Trying 141.193.213.21:443...
* TCP_NODELAY set
* Connected to aviatrix.com (141.193.213.21) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use h2
* Server certificate:
*  subject: C=US; ST=California; L=San Francisco; O=Cloudflare, Inc.; CN=aviatrix.com
*  start date: Jun 16 00:00:00 2023 GMT
*  expire date: Aug 16 17:48:10 2023 GMT
*  subjectAltName: host "aviatrix.com" matched cert's "aviatrix.com"
*  issuer: C=US; ST=TX; O=CSE; OU=DCF; CN=dcf.cse.org; emailAddress=jcortes@aviatrix.com
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x559bba9028d0)
> HEAD / HTTP/2
> Host: aviatrix.com
> user-agent: curl/7.68.0
> accept: */*
> 
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* Connection state changed (MAX_CONCURRENT_STREAMS == 100)!
< HTTP/2 200 
HTTP/2 200 
```
Notice how now the issuer is the CA Certificate uplodaed into CoPilot `issuer: C=US; ST=TX; O=CSE; OU=DCF; CN=dcf.cse.org; emailAddress=jcortes@aviatrix.com`


You can call the `/api/tls?host=ANY_FQDN` API exposed by the Kubernetes clusters and get the TLS certificates from any publicly accessible webiste. These applications are running on the worker nodes in the `prod-smart-group`:

```
avxuser@az-dev1-10:~$ curl https://gke-ingress.aviatrix.internal/api/tls?host=aviatrix.com
{
  "certificates": [
    {
      "commonName": "aviatrix.com",
      "country": "US",
      "issuer": "<X509Name object '/C=US/O=Cloudflare, Inc./CN=Cloudflare Inc ECC CA-3'>",
      "keySize": "256",
      "locality": "San Francisco",
      "organization": "Cloudflare, Inc.",
      "organizationUnit": "None",
      "serialNumber": "11718486122241929479286290696119133159",
      "state": "California",
      "subjectAlternativeNames": "None",
      "validFrom": "b'20230616000000Z'",
      "validTo": "b'20240614235959Z'"
    },
    {
      "commonName": "Cloudflare Inc ECC CA-3",
      "country": "US",
      "issuer": "<X509Name object '/C=IE/O=Baltimore/OU=CyberTrust/CN=Baltimore CyberTrust Root'>",
      "keySize": "256",
      "locality": "None",
      "organization": "Cloudflare, Inc.",
      "organizationUnit": "None",
      "serialNumber": "13580602362388610137601344763287833660",
      "state": "None",
      "subjectAlternativeNames": "None",
      "validFrom": "b'20200127124808Z'",
      "validTo": "b'20241231235959Z'"
    }
  ],
  "hostHeader": "aviatrix.com",
  "hostIpv4": "141.193.213.21",
  "httpResponseCode": 403
}
```

Now create another rule from `prod-smart-group` to `AnyWeb` web group for TCP port 443 and enable `TLS Decryption` and `Intrusion Detection (IDS)` and observe the output again, paying attention to the `issuer` field:

```
avxuser@az-dev1-10:~$ curl https://gke-ingress.aviatrix.internal/api/tls?host=aviatrix.com
{
  "certificates": [
    {
      "commonName": "aviatrix.com",
      "country": "US",
      "issuer": "<X509Name object '/C=US/ST=TX/O=CSE/OU=DCF/CN=dcf.cse.org/emailAddress=jcortes@aviatrix.com'>",
      "keySize": "2048",
      "locality": "San Francisco",
      "organization": "Cloudflare, Inc.",
      "organizationUnit": "None",
      "serialNumber": "12358",
      "state": "California",
      "subjectAlternativeNames": "None",
      "validFrom": "b'20230616000000Z'",
      "validTo": "b'20230816181507Z'"
    }
  ],
  "hostHeader": "aviatrix.com",
  "hostIpv4": "141.193.213.21",
  "httpResponseCode": 403
}
```


In the AKS, EKS and GKE clusters there is a pod named `dev-pod` which is running the container image for `Ubuntu 22.04` and is created in the `dev-nodes` node-pool. You can connect to this pod and test connectivity to the services in the same cluster, which are all deployed to the `prod-nodes` node pool:

```
kubectl exec -n dev -it dev-pod -- /bin/bash
root@dev-pod:/# curl eks-myip-svc.prod:8080/api/ip
root@dev-pod:/# curl eks-myip-svc.prod:8080/api/ip
{
  "my_default_gateway": "169.254.1.1", 
  "my_dns_servers": "['172.20.0.10']", 
  "my_private_ip": "10.20.20.37", 
  "my_public_ip": "100.20.148.237", 
  "path_accessed": "eks-myip-svc.prod:8080/api/ip", 
  "x-forwarded-for": null, 
  "your_address": "10.20.20.77", 
  "your_browser": "None", 
  "your_platform": "None"
}
root@dev-pod:/# 
```

You can then apply intra-subnet firewall rules (only enforced for AWS and Azure) to deny communication on TCP port 5000 between dev and prod smart-groups and observe how the behavior changes:

```
root@dev-pod:/# curl eks-myip-svc.prod:8080/api/ip
curl: (6) Could not resolve host: eks-myip-svc.prod
```

It appears name resolution is broken. This probably is because the DNS pods are only hosted on the prod node pool due to the taint added to the dev node pool. Let's try with clusterIP instead, since the pod is in the same cluster:

```
jcortes@linux-vm:~$ kubectl get svc -n prod
NAME               TYPE           CLUSTER-IP      EXTERNAL-IP                                                 PORT(S)          AGE
eks-getcerts-svc   LoadBalancer   172.20.65.138   getcerts-svc-d4dd23a48fc130c5.elb.us-west-2.amazonaws.com   5000:31048/TCP   3h1m
eks-myip-svc       LoadBalancer   172.20.118.69   myipap-svc-89e0a37681347188.elb.us-west-2.amazonaws.com     8080:31778/TCP   3h1m

jcortes@linux-vm:~$ kubectl exec -n dev -it dev-pod -- /bin/bash

root@dev-pod:/# # Test with eks-getcerts-svc on port 5000
root@dev-pod:/# curl 172.20.65.138:5000/api/healthcheck
curl: (28) Failed to connect to 172.20.65.138 port 5000 after 130533 ms: Connection timed out

root@dev-pod:/# # Now test with eks-myip-svc on port 8080
root@dev-pod:/# curl 172.20.118.69:8080/api/healthcheck
{
  "health": "OK"
}

```