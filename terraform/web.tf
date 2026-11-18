# ==============================================================================
# Apartados 1, 2 y 3: Deployment escalable de Servidores Web (dgsgiros/nginx-ssh:latest)
#   - 3 replicas iniciales (escalables horizontalmente)
#   - Interfaz secundaria Multus en VLAN 1000 con IPAM DHCP
#   - Opcion B (initContainer): genera /usr/share/nginx/html/index.html desde ConfigMap (RO)
#     sustituyendo __POD_NAME__ hacia un volumen compartido emptyDir (RW)
#   - Clave publica SSH (Par 1) montada desde Secret con fsGroup: 1000 y preparada en ~/.ssh
# ==============================================================================

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web-deployment"
    namespace = var.namespace
    labels = {
      app        = "web"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = var.web_replicas

    selector {
      match_labels = local.web_labels
    }

    template {
      metadata {
        labels = merge(local.web_labels, {
          role = "webserver"
        })
        annotations = {
          "k8s.v1.cni.cncf.io/networks" = local.vlan_dhcp_nad_name
          "cnvr.upm.es/template-hash"   = sha256(kubernetes_config_map_v1.web_html_template.data["index.html"])
        }
      }

      spec {
        security_context {
          fs_group = 1000
        }

        # Opcion B (Apartado 3.2): initContainer para generar la pagina HTML personalizada
        init_container {
          name  = "generate-html"
          image = "dgsgiros/nginx-ssh:latest"

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name  = "GROUP_NUMBER"
            value = var.group_number
          }

          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              set -e
              sed -e "s/__POD_NAME__/$${POD_NAME}/g" \
                  -e "s/__NODE_NAME__/$${NODE_NAME}/g" \
                  -e "s/__POD_IP__/$${POD_IP}/g" \
                  -e "s/__GROUP_NUMBER__/$${GROUP_NUMBER}/g" \
                  /mnt/html-template/index.html > /usr/share/nginx/html/index.html
              chmod 0644 /usr/share/nginx/html/index.html
            EOT
          ]

          volume_mount {
            name       = "html-template-vol"
            mount_path = "/mnt/html-template"
            read_only  = true
          }

          volume_mount {
            name       = "html-shared-vol"
            mount_path = "/usr/share/nginx/html"
          }
        }

        # initContainer ejecutado como webuser (UID/GID 1000): lee el Secret gracias a fsGroup:1000
        # y ajusta los permisos estrictos (0700 / 0600) requeridos por OpenSSH en ~/.ssh
        init_container {
          name  = "setup-ssh-auth"
          image = "dgsgiros/nginx-ssh:latest"

          security_context {
            run_as_user  = 1000
            run_as_group = 1000
          }

          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              set -e
              mkdir -p /ssh-dir/dotssh
              chmod 0700 /ssh-dir/dotssh
              cp /mnt/ssh-secret/authorized_keys /ssh-dir/dotssh/authorized_keys
              chmod 0600 /ssh-dir/dotssh/authorized_keys
            EOT
          ]

          volume_mount {
            name       = "ssh-authkeys-secret"
            mount_path = "/mnt/ssh-secret"
            read_only  = true
          }

          volume_mount {
            name       = "web-ssh-dir"
            mount_path = "/ssh-dir"
          }
        }

        container {
          name  = "nginx-ssh"
          image = "dgsgiros/nginx-ssh:latest"

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          port {
            name           = "ssh"
            container_port = 22
            protocol       = "TCP"
          }

          volume_mount {
            name       = "html-shared-vol"
            mount_path = "/usr/share/nginx/html"
          }

          volume_mount {
            name       = "web-ssh-dir"
            mount_path = "/home/webuser/.ssh"
            sub_path   = "dotssh"
          }

          volume_mount {
            name       = "ssh-authkeys-secret"
            mount_path = "/etc/ssh-secrets/pub"
            read_only  = true
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }

        # Volumen 1 (Apartado 3.3): ConfigMap con la plantilla HTML en modo solo lectura
        volume {
          name = "html-template-vol"
          config_map {
            name         = kubernetes_config_map_v1.web_html_template.metadata[0].name
            default_mode = "0444"
          }
        }

        # Volumen 2 (Apartado 3.3): Volumen compartido de lectura/escritura entre initContainer y Nginx
        volume {
          name = "html-shared-vol"
          empty_dir {}
        }

        # Volumen Secret con la clave publica autorizada del servidor de administracion
        volume {
          name = "ssh-authkeys-secret"
          secret {
            secret_name  = kubernetes_secret_v1.web_ssh_authkeys.metadata[0].name
            default_mode = "0440"
            items {
              key  = "authorized_keys"
              path = "authorized_keys"
              mode = "0440"
            }
          }
        }

        volume {
          name = "web-ssh-dir"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.vlan_dhcp
  ]
}
