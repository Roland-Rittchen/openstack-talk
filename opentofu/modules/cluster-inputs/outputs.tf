output "image_id" { value = data.openstack_images_image_v2.node.id }
output "control_plane_flavor" { value = local.control_plane_flavor }
output "control_plane_flavor_id" { value = data.openstack_compute_flavor_v2.control_plane.id }
output "worker_flavor" { value = local.worker_flavor }
output "availability_zones" { value = var.availability_zones }
output "network_id" { value = var.network_id }
output "secgroup_ids" { value = var.secgroup_ids }
