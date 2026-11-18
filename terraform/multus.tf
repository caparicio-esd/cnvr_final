# ==============================================================================
# Apartado 2.3: Configuracion de Multus mediante recursos CRD NetworkAttachmentDefinition
# Se usa kubernetes_manifest al tratarse de un Custom Resource Definition (k8s.cni.cncf.io/v1)
#   1. vlan1000-static: IP estatica para el Pod de administracion (10.1.2.10/24)
#   2. vlan1000-dhcp:   IP dinamica via DHCP en la VLAN para escalabilidad horizontal Web
# ==============================================================================

resource "kubernetes_manifest" "vlan_static" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name      = local.vlan_static_nad_name
      namespace = var.namespace
    }
    spec = {
      config = jsonencode({
        cniVersion   = "0.3.1"
        name         = local.vlan_static_nad_name
        type         = "macvlan"
        master       = "${var.worker_vlan_parent_iface}.${var.vlan_id}"
        mode         = "bridge"
        capabilities = { ips = true }
        ipam = {
          type = "static"
        }
      })
    }
  }

  field_manager {
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "vlan_dhcp" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name      = local.vlan_dhcp_nad_name
      namespace = var.namespace
    }
    spec = {
      config = jsonencode({
        cniVersion = "0.3.1"
        name       = local.vlan_dhcp_nad_name
        type       = "macvlan"
        master     = "${var.worker_vlan_parent_iface}.${var.vlan_id}"
        mode       = "bridge"
        ipam = {
          type = "dhcp"
        }
      })
    }
  }

  field_manager {
    force_conflicts = true
  }
}
