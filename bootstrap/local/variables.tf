variable "flavors" {
  type = map(object({ name = string, vcpus = number, ram_mib = number, disk_gib = number }))
}

variable "external_network" {
  type = object({
    name             = string
    physical_network = string
    cidr             = string
    gateway          = string
    allocation_start = string
    allocation_end   = string
    dns_nameservers  = list(string)
  })
}
