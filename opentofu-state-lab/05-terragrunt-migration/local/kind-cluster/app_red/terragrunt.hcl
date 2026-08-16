# -------------------------------------------------------------------
# Red App component
# Uses the shared app module with red-specific inputs
# -------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../nginx-fabric"]
}

terraform {
  source = "../../../modules/app"
}

inputs = {
  app_name   = "red"
  app_color  = "#dc3545"
  app_emoji  = "🔴"
  app_path   = "/"
  private_ip = "" # Auto-detected; override with TF_VAR_private_ip
}
