# ==============================================================================
# Apartados 2 y 5.3: Pod del Servidor de Administracion (dgsgiros/admin-ssh:latest)
#   - Desplegado en k8s-worker1 mediante nodeSelector (requerido por externalTrafficPolicy: Local)
#   - Interfaz adicional Multus en VLAN 1000 con IP fija (10.1.2.10/24)
#   - securityContext.fsGroup = 1000 para lectura de los 2 recursos Secret independientes:
#       * admin-ssh-privkey  (clave privada Par 1: admin -> web/LXC)
#       * admin-ssh-authkeys (clave publica Par 2: host -> admin)
# ==============================================================================

resource "kubernetes_pod_v1" "admin" {
  metadata {
    name      = "admin"
    namespace = var.namespace
    labels = merge(local.admin_labels, {
      role       = "management"
      managed-by = "terraform"
    })
    annotations = {
      "k8s.v1.cni.cncf.io/networks" = jsonencode([
        {
          name = local.vlan_static_nad_name
          ips  = ["${var.admin_vlan_ip}/24"]
        }
      ])
    }
  }

  spec {
    node_selector = {
      "kubernetes.io/hostname" = var.admin_target_node
    }

    security_context {
      fs_group = 1000
    }

    # ejecutado como adminuser (UID/GID 1000): aprovecha fsGroup=1000 y mode=0440 para leer
    # ambos Secrets e instalarlos en ~/.ssh con permisos 0600 requeridos por el cliente OpenSSH
    init_container {
      name  = "setup-admin-ssh"
      image = "dgsgiros/admin-ssh:latest"

      security_context {
        run_as_user  = 1000
        run_as_group = 1000
      }

      command = [
        "/bin/sh",
        "-c",
        <<-EOT
          set -e
          chmod 0700 /ssh-dir
          cp /mnt/ssh-priv/id_rsa /ssh-dir/id_rsa
          chmod 0600 /ssh-dir/id_rsa
          cp /mnt/ssh-pub/authorized_keys /ssh-dir/authorized_keys
          chmod 0600 /ssh-dir/authorized_keys
          cat > /ssh-dir/config <<'SSHCFG'
          Host 10.1.2.*
            IdentityFile ~/.ssh/id_rsa
            StrictHostKeyChecking accept-new
            UserKnownHostsFile ~/.ssh/known_hosts
          SSHCFG
          chmod 0600 /ssh-dir/config
        EOT
      ]

      volume_mount {
        name       = "ssh-private-key"
        mount_path = "/mnt/ssh-priv"
        read_only  = true
      }

      volume_mount {
        name       = "ssh-authorized-keys"
        mount_path = "/mnt/ssh-pub"
        read_only  = true
      }

      volume_mount {
        name       = "admin-ssh-dir"
        mount_path = "/ssh-dir"
      }
    }

    container {
      name  = "admin-ssh"
      image = "dgsgiros/admin-ssh:latest"

      port {
        name           = "ssh"
        container_port = 22
        protocol       = "TCP"
      }

      volume_mount {
        name       = "admin-ssh-dir"
        mount_path = "/home/adminuser/.ssh"
      }

      volume_mount {
        name       = "ssh-private-key"
        mount_path = "/etc/ssh-secrets/priv"
        read_only  = true
      }

      volume_mount {
        name       = "ssh-authorized-keys"
        mount_path = "/etc/ssh-secrets/pub"
        read_only  = true
      }
    }

    # Recurso Secret 1: clave privada para acceder a servidores web y contenedores LXC
    volume {
      name = "ssh-private-key"
      secret {
        secret_name  = kubernetes_secret_v1.admin_ssh_privkey.metadata[0].name
        default_mode = "0440"
        items {
          key  = "id_rsa"
          path = "id_rsa"
          mode = "0440"
        }
      }
    }

    # Recurso Secret 2: clave publica autorizada para el acceso desde el exterior (host)
    volume {
      name = "ssh-authorized-keys"
      secret {
        secret_name  = kubernetes_secret_v1.admin_ssh_authkeys.metadata[0].name
        default_mode = "0440"
        items {
          key  = "authorized_keys"
          path = "authorized_keys"
          mode = "0440"
        }
      }
    }

    volume {
      name = "admin-ssh-dir"
      empty_dir {}
    }
  }

  depends_on = [
    kubernetes_manifest.vlan_static
  ]
}
