variable "name" { type = string }
variable "endpoint" { type = string }
variable "region" { type = string }
variable "versioning_status" {
  type    = string
  default = "Disabled"
  validation {
    condition     = contains(["Disabled", "Enabled", "Suspended"], var.versioning_status)
    error_message = "Choose Disabled for unmanaged versioning, or explicit Enabled/Suspended."
  }
}
variable "force_destroy" {
  type    = bool
  default = false
}
