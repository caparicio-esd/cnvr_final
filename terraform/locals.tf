# ==============================================================================
# Etiquetas globales compartidas (patron 'locals' de la Practica 1.4, Apdo. 3.2)
# Evita desincronizacion de selectores entre Deployments, Pods, Services y NetworkPolicies
# ==============================================================================

locals {
  web_labels = {
    app = "web"
  }

  admin_labels = {
    app = "admin"
  }

  vlan_static_nad_name = "vlan${var.vlan_id}-static"
  vlan_dhcp_nad_name   = "vlan${var.vlan_id}-dhcp"
}
