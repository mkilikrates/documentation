variable "app_name" {
  description = "Name of the application (e.g., red, blue, green)"
  type        = string
}

variable "app_color" {
  description = "CSS background color for the app page (e.g., #dc3545)"
  type        = string
}

variable "app_emoji" {
  description = "Emoji displayed on the app page (e.g., 🔴)"
  type        = string
}

variable "app_path" {
  description = "URL path prefix for the HTTPRoute (e.g., /red)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for this app (defaults to app_name)"
  type        = string
  default     = ""
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 2
}

variable "private_ip" {
  description = "Private IP for nip.io hostname. Auto-detected if empty."
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the shared gateway to attach HTTPRoutes to"
  type        = string
  default     = "nginx-shared-gateway"
}

variable "gateway_namespace" {
  description = "Namespace of the shared gateway"
  type        = string
  default     = "nginx-gateway"
}
