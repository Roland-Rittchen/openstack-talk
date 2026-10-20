terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}
provider "openstack" {
  cloud = var.cloud
}

provider "aws" {
  region                      = var.s3.region
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
  max_retries                 = 2
  endpoints {
    s3 = var.s3.endpoint
  }
}
