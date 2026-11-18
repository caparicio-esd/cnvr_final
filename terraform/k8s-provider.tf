# ==============================================================================
# Definicion del proveedor de Kubernetes (convencion Practica 1.4: k8s-provider.tf)
# Fijado a la version 2.23.0 empleada y validada en el nodo VNX 'terraform' del lab
# ==============================================================================

terraform {
  required_version = ">= 0.14.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}
