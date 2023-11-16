terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.64"
    }
    azuread = {
      source = "hashicorp/azuread"
      version = "~> 2.41"
    }
    google = {
      source = "hashicorp/google"
      version = "~> 4.66"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source = "hashicorp/http"
      version = "~> 3.2"
    }
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
      version = "~> 3.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
}
