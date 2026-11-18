# ==============================================================================
# Apartado 5: Configuracion de recursos NetworkPolicy (aplicadas por el CNI Calico)
#   1. default-deny-all:     Bloquea todo el trafico de entrada (Ingress) y salida (Egress)
#   2. allow-ingress-to-web: Permite HTTP (80/TCP) a los Pods web unicamente desde los Pods
#                            del Ingress Controller en el namespace 'ingress-nginx'
#   3. allow-ssh-to-admin:   Permite SSH (22/TCP) al Pod admin unicamente desde el CIDR
#                            de la IP autorizada del host en user_LAN (10.10.20.2/32)
# ==============================================================================

resource "kubernetes_network_policy_v1" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = var.namespace
  }

  spec {
    # Selecciona todos los Pods del namespace (web-deployment y admin)
    pod_selector {}

    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [
    kubernetes_deployment_v1.web,
    kubernetes_pod_v1.admin
  ]
}

resource "kubernetes_network_policy_v1" "allow_ingress_to_web" {
  metadata {
    name      = "allow-ingress-to-web"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = local.web_labels
    }

    policy_types = ["Ingress"]

    ingress {
      # Un unico bloque 'from' con namespace_selector Y pod_selector aplica un AND logico:
      # solo Pods con esas labels que ademas pertenezcan al namespace ingress-nginx.
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.ingress_controller_namespace
          }
        }

        pod_selector {
          match_labels = var.ingress_controller_pod_labels
        }
      }

      ports {
        protocol = "TCP"
        port     = "80"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_ssh_to_admin" {
  metadata {
    name      = "allow-ssh-to-admin"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = local.admin_labels
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        ip_block {
          cidr = var.authorized_host_cidr
        }
      }

      ports {
        protocol = "TCP"
        port     = "22"
      }
    }
  }
}
