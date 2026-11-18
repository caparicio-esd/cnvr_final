# ==============================================================================
# Apartado 2.5: Gestion declarativa de claves SSH mediante Kubernetes Secrets
#   - Par 1 (admin -> web/LXC): admin-ssh-privkey (privada) y web-ssh-authkeys (publica)
#   - Par 2 (host -> admin):    admin-ssh-authkeys (publica)
# ==============================================================================

resource "kubernetes_secret_v1" "admin_ssh_privkey" {
  metadata {
    name      = "admin-ssh-privkey"
    namespace = var.namespace
    labels = {
      app        = "admin"
      managed-by = "terraform"
    }
  }

  data = {
    id_rsa = file("${path.module}/${var.internal_ssh_private_key_path}")
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "admin_ssh_authkeys" {
  metadata {
    name      = "admin-ssh-authkeys"
    namespace = var.namespace
    labels = {
      app        = "admin"
      managed-by = "terraform"
    }
  }

  data = {
    authorized_keys = file("${path.module}/${var.external_ssh_public_key_path}")
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "web_ssh_authkeys" {
  metadata {
    name      = "web-ssh-authkeys"
    namespace = var.namespace
    labels = {
      app        = "web"
      managed-by = "terraform"
    }
  }

  data = {
    authorized_keys = file("${path.module}/${var.internal_ssh_public_key_path}")
  }

  type = "Opaque"
}
