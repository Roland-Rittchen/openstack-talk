packer {
  required_plugins {
    openstack = {
      source  = "github.com/hashicorp/openstack"
      version = "= 1.1.4"
    }
  }
}
variable "cloud" { type = string }
variable "source_image_name" { type = string }
variable "flavor" { type = string }
variable "external_network_name" { type = string }
variable "availability_zone" {
  type    = string
  default = ""
}
variable "network_id" { type = string }
variable "security_groups" { type = list(string) }
variable "kubernetes_version" { type = string }
variable "kubernetes_package_version" { type = string }
variable "containerd_package_version" { type = string }
variable "build_date" { type = string }
variable "image_os_distro" { type = string }
variable "image_os_version" { type = string }
locals {
  image_name = "k8s-${var.kubernetes_version}-${var.build_date}"
}
source "openstack" "kubeadm" {
  cloud                    = var.cloud
  source_image_name        = var.source_image_name
  flavor                   = var.flavor
  networks                 = [var.network_id]
  security_groups          = var.security_groups
  availability_zone        = var.availability_zone
  floating_ip_network      = var.external_network_name
  instance_floating_ip_net = var.network_id
  reuse_ips                = false
  ssh_username             = "ubuntu"
  ssh_timeout              = "10m"
  config_drive             = true
  instance_name            = "image-build-${local.image_name}"
  image_name               = local.image_name
  image_visibility         = "private"
  metadata = {
    os_distro                  = var.image_os_distro
    os_version                 = var.image_os_version
    architecture               = "x86_64"
    hw_disk_bus                = "scsi"
    hw_scsi_model              = "virtio-scsi"
    hw_rng_model               = "virtio"
    image_build_date           = "${substr(var.build_date, 0, 4)}-${substr(var.build_date, 4, 2)}-${substr(var.build_date, 6, 2)}"
    image_original_user        = "ubuntu"
    replace_frequency          = "never"
    uuid_validity              = "none"
    provided_until             = "none"
    image_source               = "private"
    image_description          = "Private demo image; immutable dated name, Kubernetes ${var.kubernetes_version}, containerd ${var.containerd_package_version}; rebuild for updates."
    kubernetes_version         = var.kubernetes_version
    containerd_package_version = var.containerd_package_version
  }
}
build {
  sources = ["source.openstack.kubeadm"]
  provisioner "shell" {
    environment_vars = [
      "KUBERNETES_VERSION=${var.kubernetes_version}",
      "KUBERNETES_PACKAGE_VERSION=${var.kubernetes_package_version}",
      "CONTAINERD_PACKAGE_VERSION=${var.containerd_package_version}"
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/provision.sh"
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo bash '{{ .Path }}'"
    script          = "${path.root}/scripts/seal.sh"
  }
  post-processor "manifest" {
    output     = "${path.root}/../.generated/${var.cloud}-image-manifest.json"
    strip_path = true
    custom_data = {
      image_name                 = local.image_name
      kubernetes_version         = var.kubernetes_version
      containerd_package_version = var.containerd_package_version
    }
  }
}
