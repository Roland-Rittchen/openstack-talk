module "network" {
  source                = "../network"
  name_prefix           = var.name_prefix
  cidr                  = var.cidr
  dns_nameservers       = var.dns_nameservers
  external_network_name = var.external_network_name
  tags                  = var.tags
  api_client_cidrs      = var.api_client_cidrs
  admin_cidrs           = var.admin_cidrs
}

module "cluster_inputs" {
  source             = "../cluster-inputs"
  image_name         = var.image_name
  flavor_map         = var.flavor_map
  control_plane_size = var.control_plane_size
  worker_size        = var.worker_size
  availability_zones = var.availability_zones
  network_id         = module.network.network_id
  secgroup_ids       = module.network.secgroup_ids
}

resource "openstack_compute_keypair_v2" "admin" {
  name       = "${var.name_prefix}-admin"
  public_key = var.ssh_public_key
}

resource "openstack_networking_port_v2" "control_plane" {
  name               = "${var.name_prefix}-control-plane"
  network_id         = module.network.network_id
  admin_state_up     = true
  security_group_ids = [module.network.secgroup_ids["control-plane"]]
  fixed_ip {
    subnet_id = module.network.subnet_id
  }
  tags = var.tags
}

resource "openstack_compute_instance_v2" "control_plane" {
  name              = "${var.name_prefix}-control-plane"
  image_id          = module.cluster_inputs.image_id
  flavor_id         = module.cluster_inputs.control_plane_flavor_id
  key_pair          = openstack_compute_keypair_v2.admin.name
  availability_zone = length(var.availability_zones) > 0 ? var.availability_zones[0] : null
  config_drive      = true
  user_data         = local.cloud_init
  metadata          = { purpose = "openstack-talk-phase-1" }
  network {
    port = openstack_networking_port_v2.control_plane.id
  }
  # Wait for router/subnet wiring and security-group rules before booting.
  depends_on = [module.network]
}

resource "openstack_networking_floatingip_v2" "control_plane" {
  pool        = var.external_network_name
  description = "${var.name_prefix} control-plane access"
  depends_on  = [module.network]
}

resource "openstack_networking_floatingip_associate_v2" "control_plane" {
  floating_ip = openstack_networking_floatingip_v2.control_plane.address
  port_id     = openstack_networking_port_v2.control_plane.id
  depends_on  = [module.network]
}

resource "openstack_blockstorage_volume_v3" "data" {
  name              = "${var.name_prefix}-data"
  size              = var.data_volume_size
  volume_type       = var.volume_type_map[var.volume_size_key]
  availability_zone = var.volume_availability_zone
  metadata          = { purpose = "openstack-talk-phase-1" }
}

resource "openstack_compute_volume_attach_v2" "data" {
  instance_id = openstack_compute_instance_v2.control_plane.id
  volume_id   = openstack_blockstorage_volume_v3.data.id
}

module "buckets" {
  source            = "../bucket"
  for_each          = toset(concat(["state", "backup"], var.s3.retain_state_archive ? ["state-archive"] : []))
  name              = "${var.name_prefix}-${each.key == "state" ? "state-current" : each.key == "state-archive" ? "state" : each.key}-${substr(sha256(var.s3.namespace), 0, 12)}"
  endpoint          = var.s3.endpoint
  region            = var.s3.region
  force_destroy     = false
  versioning_status = each.key == "state-archive" ? "Suspended" : each.key == "state" ? var.s3.state_versioning_status : "Disabled"
}
