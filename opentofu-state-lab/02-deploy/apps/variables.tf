variable "private_ip" {
  description = "Private IP of the host machine (used for nip.io DNS). Auto-detected if not set. Override with: export TF_VAR_private_ip=\"your.ip\""
  type        = string
  default     = ""
}
