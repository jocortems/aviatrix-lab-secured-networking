provider "azurerm" {
  features {
    resource_group {
        prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

provider "aws" {
  region = "us-west-2"
  access_key = ""
  secret_key = ""
}

provider "google" {
  region = "us-west1"
  project = ""
  credentials = file("")
}

provider "http" {}

provider "aviatrix" {
  controller_ip           = ""
  username                = ""
  password                = ""
  skip_version_validation = true
  verify_ssl_certificate  = false
}
