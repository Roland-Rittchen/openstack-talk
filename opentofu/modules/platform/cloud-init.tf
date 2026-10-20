locals {
  cloud_init = "#cloud-config\n${yamlencode({
    hostname         = "platform-control-plane"
    manage_etc_hosts = true
    disable_root     = true
    ssh_pwauth       = false
    package_update   = true
    packages         = concat(["unattended-upgrades", "curl"], length(var.trusted_ca_certificates) > 0 ? ["ca-certificates"] : [])
    write_files = concat([
      {
        path    = "/etc/ssh/sshd_config.d/00-platform.conf", permissions = "0644"
        content = "PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n"
      },
      {
        path    = "/etc/apt/apt.conf.d/20auto-upgrades", permissions = "0644"
        content = "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n"
      },
      {
        path = "/etc/openstack-talk/bootstrap.env", permissions = "0600"
        content = join("\n", [
          "K3S_VERSION='${var.bootstrap.version}'", "K3S_BINARY_URL='${var.bootstrap.binary_url}'",
          "K3S_SHA256='${var.bootstrap.sha256}'", "DATA_VOLUME_ID='${openstack_blockstorage_volume_v3.data.id}'",
          "DATA_VOLUME_SIZE='${var.data_volume_size}'", ""
        ])
      },
      {
        path    = "/etc/openstack-talk/bootstrap-k3s.sh", permissions = "0700"
        content = file("${path.module}/bootstrap-k3s.sh")
      },
      {
        path    = "/etc/openstack-talk/mount-data-volume.sh", permissions = "0700"
        content = file("${path.module}/mount-data-volume.sh")
      },
      {
        path = "/etc/rancher/k3s/config.yaml", permissions = "0600"
        content = yamlencode(merge({
          "data-dir"                   = "/mnt/platform-data/k3s"
          "default-local-storage-path" = "/mnt/platform-data/workloads"
          "write-kubeconfig-mode"      = "0600"
          "secrets-encryption"         = true
          "disable"                    = ["traefik", "servicelb"]
          "disable-cloud-controller"   = true
          "tls-san"                    = [openstack_networking_floatingip_v2.control_plane.address]
        }, length(var.dns_routing_domains) > 0 ? { "resolv-conf" = "/run/systemd/resolve/resolv.conf" } : {}))
      }
      ], length(var.dns_routing_domains) > 0 ? [{
        path        = "/etc/systemd/resolved.conf.d/50-platform-dns.conf"
        permissions = "0644"
        content     = "[Resolve]\nDNS=${join(" ", var.dns_nameservers)}\nDomains=${join(" ", [for domain in var.dns_routing_domains : "~${domain}"])}\n"
        }] : [], [for index, cert in var.trusted_ca_certificates : {
        path        = "/usr/local/share/ca-certificates/platform-${index}.crt"
        permissions = "0644"
        content     = cert
    }])
    runcmd = concat(
      length(var.trusted_ca_certificates) > 0 ? ["update-ca-certificates"] : [],
      length(var.dns_routing_domains) > 0 ? ["systemctl restart systemd-resolved"] : [],
      ["bash /etc/openstack-talk/bootstrap-k3s.sh"]
    )
  })}"
}
