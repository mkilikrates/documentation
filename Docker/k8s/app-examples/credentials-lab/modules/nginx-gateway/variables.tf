variable "control_plane_node" {
  description = "Node name for the control-plane (Kind-specific pinning)"
  type        = string
  default     = "credentials-lab-control-plane"
}

variable "domain" {
  description = "Wildcard domain for the gateway (e.g., 192.168.1.10.nip.io)"
  type        = string
}
