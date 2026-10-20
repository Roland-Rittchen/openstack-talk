# Cloud-admin prerequisites; separate from the portable workload platform.
resource "openstack_compute_flavor_v2" "demo" {
  for_each  = var.flavors
  name      = each.value.name
  vcpus     = each.value.vcpus
  ram       = each.value.ram_mib
  disk      = each.value.disk_gib
  is_public = true
}

resource "openstack_networking_network_v2" "external" {
  name           = var.external_network.name
  description    = "Local cloud external network for the OpenStack talk"
  admin_state_up = true
  external       = true
  shared         = false
  segments {
    network_type     = "flat"
    physical_network = var.external_network.physical_network
  }
}

resource "openstack_networking_subnet_v2" "external" {
  name            = "${var.external_network.name}-subnet"
  network_id      = openstack_networking_network_v2.external.id
  cidr            = var.external_network.cidr
  ip_version      = 4
  gateway_ip      = var.external_network.gateway
  enable_dhcp     = false
  dns_nameservers = var.external_network.dns_nameservers
  allocation_pool {
    start = var.external_network.allocation_start
    end   = var.external_network.allocation_end
  }
}

output "bootstrap" {
  value = {
    flavors             = { for key, flavor in openstack_compute_flavor_v2.demo : key => { id = flavor.id, name = flavor.name } }
    external_network_id = openstack_networking_network_v2.external.id
    external_subnet_id  = openstack_networking_subnet_v2.external.id
  }
}
