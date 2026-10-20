terraform {
  required_version = ">= 1.10"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "= 3.4.0"
    }
  }
  backend "local" {
    path = "../../.generated/local-bootstrap/terraform.tfstate"
  }
}

provider "openstack" {
  cloud = "local"
}
