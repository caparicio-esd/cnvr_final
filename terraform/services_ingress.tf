# ==============================================================================
# Apartado 4: Configuracion de Services e Ingress
#   1. web-service   (ClusterIP): TCP 8080 -> 80 de los Pods web
#   2. admin-service (NodePort):  TCP 2222 -> 22 del Pod admin (externalTrafficPolicy: Local)
#   3. web-ingress   (Ingress):   Ruta /servers-GX -> web-service:8080 con rewrite-target: /
# ==============================================================================

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "web-service"
    namespace = var.namespace
    labels = {
      app        = "web"
      managed-by = "terraform"
    }
  }

  spec {
    type     = "ClusterIP"
    selector = local.web_labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8080
      target_port = 80
    }
  }
}

resource "kubernetes_service_v1" "admin" {
  metadata {
    name      = "admin-service"
    namespace = var.namespace
    labels = {
      app        = "admin"
      managed-by = "terraform"
    }
  }

  spec {
    type = "NodePort"

    # Imprescindible para evitar SNAT en kube-proxy y preservar la IP origen del host (user_LAN)
    external_traffic_policy = "Local"
    selector                = local.admin_labels

    port {
      name        = "ssh"
      protocol    = "TCP"
      port        = 2222
      target_port = 22
      node_port   = var.admin_node_port
    }
  }
}

resource "kubernetes_ingress_class_v1" "nginx" {
  metadata {
    name = "nginx-ingress-class"
  }

  spec {
    controller = "k8s.io/ingress-nginx"
  }
}

resource "kubernetes_ingress_v1" "web" {
  metadata {
    name      = "web-ingress"
    namespace = var.namespace
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
    labels = {
      app        = "web"
      managed-by = "terraform"
    }
  }

  spec {
    ingress_class_name = kubernetes_ingress_class_v1.nginx.metadata[0].name

    rule {
      http {
        path {
          path      = "/servers-G${var.group_number}"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.web.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
