output "network_id" { value = openstack_networking_network_v2.private.id }
output "subnet_id" { value = openstack_networking_subnet_v2.private.id }
output "router_id" { value = openstack_networking_router_v2.gateway.id }
output "api_server_access_cidrs" { value = concat([var.cidr, "${local.router_ipv4}/32"], sort(tolist(var.api_client_cidrs))) }
output "external_network_id" { value = data.openstack_networking_network_v2.external.id }
output "secgroup_ids" { value = { for role, group in openstack_networking_secgroup_v2.nodes : role => group.id } }
