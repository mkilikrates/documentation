provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "kind-kind"
  }
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}
