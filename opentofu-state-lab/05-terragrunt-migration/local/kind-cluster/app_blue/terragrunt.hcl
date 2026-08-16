# -------------------------------------------------------------------
# Blue App component
# Uses the shared app module with blue-specific inputs
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
  app_name   = "blue"
  app_color  = "#0d6efd"
  app_emoji  = "🔵"
  app_path   = "/"
  private_ip = "" # Auto-detected; override with TF_VAR_private_ip
}
