variable "name_prefix" { type = string }
variable "cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "cidr must be an IPv4 subnet."
  }
}
variable "dns_nameservers" { type = list(string) }
variable "external_network_name" { type = string }
variable "tags" { type = list(string) }
variable "admin_cidrs" {
  description = "Explicit IPv4 sources permitted to SSH, the API, and NodePort services."
  type        = set(string)
  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Provide restricted IPv4 admin CIDRs, never the entire Internet."
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
