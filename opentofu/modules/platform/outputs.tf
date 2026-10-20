output "network_id" { value = module.network.network_id }
output "subnet_id" { value = module.network.subnet_id }
output "router_id" { value = module.network.router_id }
output "api_server_access_cidrs" { value = module.network.api_server_access_cidrs }
output "secgroup_ids" { value = module.network.secgroup_ids }
output "external_network_id" { value = module.network.external_network_id }
output "image_id" { value = module.cluster_inputs.image_id }
output "control_plane_flavor" { value = module.cluster_inputs.control_plane_flavor }
output "worker_flavor" { value = module.cluster_inputs.worker_flavor }
output "availability_zones" { value = module.cluster_inputs.availability_zones }
output "instance_id" { value = openstack_compute_instance_v2.control_plane.id }
output "floating_ip" { value = openstack_networking_floatingip_v2.control_plane.address }
output "data_volume_id" { value = openstack_blockstorage_volume_v3.data.id }
output "data_volume_size" { value = var.data_volume_size }
output "ssh_command" { value = "ssh ubuntu@${openstack_networking_floatingip_v2.control_plane.address}" }

output "buckets" { value = { for purpose, bucket in module.buckets : purpose => bucket.bucket_name } }
output "s3_endpoint" { value = var.s3.endpoint }
output "s3_region" { value = var.s3.region }
output "ssh_key_name" { value = openstack_compute_keypair_v2.admin.name }
output "cidr" { value = var.cidr }
output "dns_nameservers" { value = var.dns_nameservers }
output "dns_routing_domains" { value = var.dns_routing_domains }
