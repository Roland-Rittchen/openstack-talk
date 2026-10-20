data "openstack_images_image_v2" "node" {
  name        = var.image_name
  most_recent = true
}

# Direct indexing deliberately fails on a missing logical size. Phase 1 resolves
# image/flavor inputs; CAPO credential creation belongs to the later CAPI phase.
locals {
  control_plane_flavor = var.flavor_map[var.control_plane_size]
  worker_flavor        = var.flavor_map[var.worker_size]
}

data "openstack_compute_flavor_v2" "control_plane" {
  name = local.control_plane_flavor
}
