# Auto-detect private IP from the default route interface.
# Works on Linux (including WSL) and macOS.
# Override by setting: export TF_VAR_private_ip="your.ip.here"

data "external" "host_ip" {
  count   = var.private_ip == "" ? 1 : 0
  program = ["bash", "${path.module}/detect-ip.sh"]
}

locals {
  private_ip = var.private_ip != "" ? var.private_ip : data.external.host_ip[0].result.ip
}
