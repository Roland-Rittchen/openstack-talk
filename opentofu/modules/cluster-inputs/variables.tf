variable "image_name" { type = string }
variable "flavor_map" { type = map(string) }
variable "control_plane_size" { type = string }
variable "worker_size" { type = string }
variable "availability_zones" { type = list(string) }
variable "network_id" { type = string }
variable "secgroup_ids" { type = map(string) }
