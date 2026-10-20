variable "cloud" { type = string }
variable "name_prefix" { type = string }
variable "cidr" { type = string }
variable "dns_nameservers" { type = list(string) }
variable "trusted_ca_certificates" {
  description = "Optional PEM CA certificates installed in the guest trust store."
  type        = list(string)
  default     = []
}
variable "dns_routing_domains" {
  description = "Optional guest domains routed to the environment DNS servers."
  type        = list(string)
  default     = []
}
variable "external_network_name" { type = string }
variable "tags" { type = list(string) }
variable "admin_cidrs" { type = set(string) }
variable "image_name" { type = string }
variable "flavor_map" { type = map(string) }
variable "control_plane_size" { type = string }
variable "worker_size" { type = string }
variable "availability_zones" { type = list(string) }
variable "volume_availability_zone" {
  description = "Storage zone independent of compute placement; null uses the cloud default."
  type        = string
  default     = null
}
variable "ssh_public_key" {
  type = string
  validation {
    condition     = can(regex("^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+", var.ssh_public_key))
    error_message = "Provide an OpenSSH public key, never a private key."
  }
}
variable "volume_type_map" { type = map(string) }
variable "volume_size_key" { type = string }
variable "data_volume_size" {
  type = number
  validation {
    condition     = var.data_volume_size >= 1 && var.data_volume_size == floor(var.data_volume_size)
    error_message = "Data volume size must be a positive integer in GiB."
  }
}
variable "enable_octavia" {
  description = "Workload API/ingress preference: apply the matching CAPI and Flux overlay; the foundation uses a floating IP."
  type        = bool
}

variable "s3" {
  description = "Endpoint-mode object storage settings, including a unique namespace."
  type        = object({ endpoint = string, region = string, namespace = string, state_versioning_status = optional(string, "Disabled"), retain_state_archive = optional(bool, false) })
  validation {
    condition     = can(regex("^https:/{2}[^@?#]+$", var.s3.endpoint)) && length(var.s3.namespace) > 0
    error_message = "Provide an HTTPS S3 endpoint and a nonempty bucket namespace."
  }
}

variable "api_client_cidrs" {
  description = "Additional explicit IPv4 API-only clients, including floating-IP return paths."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for cidr in var.api_client_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Provide restricted IPv4 API client CIDRs, never the entire Internet."
  }
}
