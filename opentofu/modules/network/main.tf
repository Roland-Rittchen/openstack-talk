data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}

resource "openstack_networking_network_v2" "private" {
  name           = "${var.name_prefix}-private"
  admin_state_up = true
  tags           = var.tags
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.name_prefix}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers
  tags            = var.tags
}

resource "openstack_networking_router_v2" "gateway" {
  name                = "${var.name_prefix}-gateway"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
  tags                = var.tags
  # Keep the cloud's default SNAT behavior; explicitly toggling it can require
  # additional privileges. No vendor-specific QoS policy is selected here.
}

resource "openstack_networking_router_interface_v2" "private" {
  router_id = openstack_networking_router_v2.gateway.id
  subnet_id = openstack_networking_subnet_v2.private.id
}

resource "openstack_networking_secgroup_v2" "nodes" {
  for_each             = toset(["control-plane", "worker"])
  name                 = "${var.name_prefix}-${each.key}"
  description          = "Managed ${each.key} access"
  delete_default_rules = true
  tags                 = var.tags
}

locals {
  admin_rules = merge(
    { for pair in setproduct(var.admin_cidrs, toset(["control-plane", "worker"]), toset(["ssh", "nodeport"])) :
      "${pair[1]}-${pair[2]}-${pair[0]}" => {
        role = pair[1], cidr = pair[0], min = pair[2] == "ssh" ? 22 : 30000, max = pair[2] == "ssh" ? 22 : 32767
      }
    },
    { for cidr in var.admin_cidrs : "control-plane-api-${cidr}" => { role = "control-plane", cidr = cidr, min = 6443, max = 6443 } }
  )
  egress = {
    for pair in setproduct(["control-plane", "worker"], ["IPv4", "IPv6"]) :
    "${pair[0]}-${pair[1]}" => { role = pair[0], ethertype = pair[1] }
  }
}

resource "openstack_networking_secgroup_rule_v2" "admin" {
  for_each          = local.admin_rules
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.min
  port_range_max    = each.value.max
  remote_ip_prefix  = each.value.cidr
  security_group_id = openstack_networking_secgroup_v2.nodes[each.value.role].id
}

# Nodes and management controllers can reach their floating API endpoint via
# router SNAT. Preserve that API path without granting SSH/NodePort access.
locals {
  router_ipv4 = one([
    for address in openstack_networking_router_v2.gateway.external_fixed_ip : address.ip_address
    if can(cidrnetmask("${address.ip_address}/32"))
  ])
}

resource "openstack_networking_secgroup_rule_v2" "api_router" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "${local.router_ipv4}/32"
  security_group_id = openstack_networking_secgroup_v2.nodes["control-plane"].id
  lifecycle {
    precondition {
      condition     = local.router_ipv4 != null
      error_message = "The platform requires one IPv4 router gateway for floating API access."
    }
  }
}

resource "openstack_networking_secgroup_rule_v2" "kubelet" {
  for_each          = openstack_networking_secgroup_v2.nodes
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_ip_prefix  = var.cidr
  security_group_id = each.value.id
}

resource "openstack_networking_secgroup_rule_v2" "egress" {
  for_each          = local.egress
  direction         = "egress"
  ethertype         = each.value.ethertype
  security_group_id = openstack_networking_secgroup_v2.nodes[each.value.role].id
}

locals {
  internal_rules = merge(
    { for role in ["control-plane", "worker"] : "${role}-nodeport" => { role = role, protocol = "tcp", min = 30000, max = 32767 } },
    { for role in ["control-plane", "worker"] : "${role}-overlay" => { role = role, protocol = "udp", min = 8472, max = 8472 } },
    { "control-plane-api" = { role = "control-plane", protocol = "tcp", min = 6443, max = 6443 } },
    { "control-plane-etcd" = { role = "control-plane", protocol = "tcp", min = 2379, max = 2380 } }
  )
}
resource "openstack_networking_secgroup_rule_v2" "internal" {
  for_each          = local.internal_rules
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.min
  port_range_max    = each.value.max
  remote_ip_prefix  = var.cidr
  security_group_id = openstack_networking_secgroup_v2.nodes[each.value.role].id
}

# Explicit API-only callers whose floating source survives router translation.
resource "openstack_networking_secgroup_rule_v2" "api_client" {
  for_each          = var.api_client_cidrs
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.nodes["control-plane"].id
}
