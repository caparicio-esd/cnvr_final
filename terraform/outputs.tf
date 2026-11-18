# ==============================================================================
# Consulta dinamica de los Pods creados por el Deployment (Practica 1.4, Apdo. 3.1)
# y salidas (outputs) con los endpoints del despliegue
# ==============================================================================

data "kubernetes_resources" "web_pods" {
  api_version    = "v1"
  kind           = "Pod"
  namespace      = var.namespace
  label_selector = "app=${local.web_labels.app}"

  depends_on = [
    kubernetes_deployment_v1.web
  ]
}

output "deployment_name" {
  description = "Nombre del recurso Deployment de servidores web"
  value       = kubernetes_deployment_v1.web.metadata[0].name
}

output "deployment_replicas" {
  description = "Numero deseado de replicas en el Deployment web"
  value       = kubernetes_deployment_v1.web.spec[0].replicas
}

output "web_pod_names" {
  description = "Listado dinamico de nombres de los Pods de servidores web creados"
  value       = [for pod in data.kubernetes_resources.web_pods.objects : pod.metadata.name]
}

output "web_ingress_url" {
  description = "URL publica del servicio web a traves del Ingress Controller"
  value       = "http://${var.ingress_external_ip}/servers-G${var.group_number}"
}

output "web_service_cluster_ip" {
  description = "ClusterIP interna asignada al Service de los servidores web"
  value       = kubernetes_service_v1.web.spec[0].cluster_ip
}

output "admin_service_node_port" {
  description = "Puerto NodePort asignado para acceder por SSH al Pod de administracion"
  value       = kubernetes_service_v1.admin.spec[0].port[0].node_port
}

output "admin_ssh_command_from_host" {
  description = "Comando SSH para conectarse desde el host autorizado al Pod admin"
  value       = "ssh -i keys/id_rsa_external -p ${kubernetes_service_v1.admin.spec[0].port[0].node_port} adminuser@${var.admin_worker_ip}"
}

output "vlan_endpoints" {
  description = "Resumen de direccionamiento en la VLAN compartida con VNX"
  value = {
    vlan_id   = var.vlan_id
    admin_pod = var.admin_vlan_ip
    lxc_bbdd  = var.bbdd_vlan_ip
    lxc_logs  = var.logs_vlan_ip
    web_dhcp  = "10.1.2.50 - 10.1.2.95"
  }
}
