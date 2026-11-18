variable "kubeconfig_path" {
  description = "Ruta al fichero kubeconfig de acceso al cluster de Kubernetes"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Namespace de Kubernetes donde se despliega la aplicacion"
  type        = string
  default     = "default"
}

variable "group_number" {
  description = "Numero del grupo de practicas (X en /servers-GX)"
  type        = string
  default     = "11"
}

variable "web_replicas" {
  description = "Numero de replicas escalables del Deployment de servidores web Nginx"
  type        = number
  default     = 3

  validation {
    condition     = var.web_replicas >= 1
    error_message = "El numero de replicas web debe ser al menos 1."
  }
}

variable "vlan_id" {
  description = "Identificador IEEE 802.1Q de la VLAN compartida con el escenario VNX"
  type        = number
  default     = 1000
}

variable "worker_vlan_parent_iface" {
  description = "Interfaz de red en k8s-worker1 y k8s-worker2 conectada a VlanNet"
  type        = string
  default     = "e2"
}

variable "admin_vlan_ip" {
  description = "Direccion IPv4 estatica del Pod admin en la VLAN compartida"
  type        = string
  default     = "10.1.2.10"
}

variable "bbdd_vlan_ip" {
  description = "Direccion IPv4 del contenedor LXC de base de datos MariaDB en la VLAN"
  type        = string
  default     = "10.1.2.100"
}

variable "logs_vlan_ip" {
  description = "Direccion IPv4 del contenedor LXC de logs centralizados en la VLAN"
  type        = string
  default     = "10.1.2.101"
}

variable "admin_target_node" {
  description = "Nodo worker donde se fija el despliegue del Pod admin mediante nodeSelector"
  type        = string
  default     = "k8s-worker1"
}

variable "admin_worker_ip" {
  description = "IP en k8s_LAN del nodo k8s-worker1 para el acceso SSH externo por NodePort"
  type        = string
  default     = "10.10.10.11"
}

variable "admin_node_port" {
  description = "Puerto NodePort asignado al Service del servidor de administracion (30000-32767)"
  type        = number
  default     = 30022
}

variable "ingress_external_ip" {
  description = "IP externa asignada por MetalLB al Ingress Controller"
  type        = string
  default     = "10.10.10.20"
}

variable "authorized_host_cidr" {
  description = "CIDR del host autorizado en user_LAN para acceso SSH al Pod admin"
  type        = string
  default     = "10.10.20.2/32"
}

variable "ingress_controller_namespace" {
  description = "Namespace donde se ejecuta el Ingress Controller"
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_controller_pod_labels" {
  description = "Etiquetas (labels) que identifican a los Pods del Ingress Controller"
  type        = map(string)
  default = {
    "app.kubernetes.io/name"      = "ingress-nginx"
    "app.kubernetes.io/component" = "controller"
  }
}

variable "internal_ssh_private_key_path" {
  description = "Ruta local a la clave privada SSH del Par 1 (admin -> servidores web y LXC)"
  type        = string
  default     = "../keys/id_rsa_internal"
}

variable "internal_ssh_public_key_path" {
  description = "Ruta local a la clave publica SSH del Par 1 (autorizada en web y LXC)"
  type        = string
  default     = "../keys/id_rsa_internal.pub"
}

variable "external_ssh_public_key_path" {
  description = "Ruta local a la clave publica SSH del Par 2 (exterior -> admin)"
  type        = string
  default     = "../keys/id_rsa_external.pub"
}
