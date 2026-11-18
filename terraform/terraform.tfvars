# ==============================================================================
# Fichero de parametros cargado automaticamente por Terraform (Practica 1.4)
# Particularizado para el Grupo 11 (ruta /servers-G11) y escenario k8s_lab-calico-v02
# ==============================================================================

namespace                    = "default"
group_number                 = "11"
web_replicas                 = 3
vlan_id                      = 1000
worker_vlan_parent_iface     = "e2"
admin_vlan_ip                = "10.1.2.10"
bbdd_vlan_ip                 = "10.1.2.100"
logs_vlan_ip                 = "10.1.2.101"
admin_target_node            = "k8s-worker1"
admin_worker_ip              = "10.10.10.11"
admin_node_port              = 30022
ingress_external_ip          = "10.10.10.20"
authorized_host_cidr         = "10.10.20.2/32"
ingress_controller_namespace = "ingress-nginx"
