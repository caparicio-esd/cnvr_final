# Trabajo Final CNVR / ARSN (2026-27) — Grupo 11

**Despliegue automático de una aplicación web escalable sobre Kubernetes y VNX utilizando los servicios de orquestación de Terraform.**

- **Autor**: Carlos Aparicio de Santiago
- **Grupo**: G11 (`/servers-G11`)

## Estructura del Repositorio

```text
cnvr_final/
├── scripts/
│   ├── 01_deploy_all.sh        # Ensamblador de despliegue: ejecuta en orden pasos/01..06
│   ├── 02_verify_all.sh        # Ensamblador de pruebas: ejecuta en orden pasos/test_01..06
│   ├── 03_destroy_all.sh       # Destruccion limpia del escenario (--full para apagar tambien K8s)
│   └── pasos/                  # Mini-scripts individuales ejecutables paso a paso
│       ├── 01_claves_ssh.sh
│       ├── 02_k8s_y_terraform_vm.sh
│       ├── 03_vlan_workers.sh
│       ├── 04_vnx_lxc.sh
│       ├── 05_terraform_apply.sh
│       ├── 06_instalar_mariadb_client.sh
│       └── test_01..06_*.sh    # Verificaciones independientes por bloque
├── vnx/
│   ├── k8s_lxc_vlan.xml        # Escenario VNX con contenedores LXC 'bbdd' (10.1.2.100) y 'logs' (10.1.2.101) en VLAN 1000
│   └── conf/                   # Configuraciones inyectadas mediante <filetree> (MariaDB, Rsyslog, Dnsmasq DHCP, SSH)
├── terraform/
│   ├── k8s-provider.tf         # Proveedor hashicorp/kubernetes (version 2.23.0, igual que P1.4)
│   ├── variables.tf            # Variables tipadas de red, nodos, puertos, etiquetas y rutas de claves
│   ├── terraform.tfvars        # Fichero de parametros cargado automaticamente por Terraform (Practica 1.4)
│   ├── locals.tf               # Etiquetas globales compartidas (local.web_labels, local.admin_labels) y nombres de NADs
│   ├── secrets.tf              # 3 Kubernetes Secrets nativos para los dos pares de claves SSH
│   ├── multus.tf               # CRDs NetworkAttachmentDefinition (vlan1000-static y vlan1000-dhcp) via kubernetes_manifest
│   ├── configmap.tf            # Plantilla HTML personalizada con marcadores dinamicos
│   ├── web.tf                  # Deployment escalable (3 replicas nginx-ssh) + initContainers (Opcion B) + volumenes
│   ├── admin.tf                # Pod admin-ssh en k8s-worker1 (nodeSelector) + fsGroup:1000 + IP estatica Multus
│   ├── services_ingress.tf     # Service ClusterIP web (8080->80), NodePort admin (2222->22, Local) e Ingress (/servers-G11)
│   ├── network_policies.tf     # Politicas Zero-Trust: default-deny-all, allow-ingress-to-web y allow-ssh-to-admin
│   └── outputs.tf              # Data source kubernetes_resources (web_pod_names) y outputs de URLs, IPs y SSH
└── memoria/
    ├── main.tex                # Codigo fuente principal de la memoria tecnica en LaTeX
    ├── capitulos/              # Capitulos modulares (Linux Networking, Kubernetes, Terraform + P1.4, Decisiones y Pruebas)
    └── Trabajo_Final_CNVR.pdf  # Informe completo compilado en PDF
```

## Uso Rápido en el Laboratorio (DIT-UPM)

El script `01_deploy_all.sh` automatiza íntegramente el flujo de la **Práctica 1.4** y del **Trabajo Final**: arranca `k8s_lab-calico-v02`, levanta e instala el nodo proveedor `terraform` (`k8s_lab-terraform.xml`, `10.10.10.13`), exporta credenciales (`get-master-kubeconf` y `set-terraform-kubeconf`), sincroniza las plantillas HCL en la carpeta compartida `/shared`, despliega el escenario VNX complementario (`bbdd` y `logs`) y ejecuta `terraform init / validate / plan / apply`.

```bash
# 1. Desplegar toda la infraestructura y aplicacion de principio a fin (o ejecutar pasos/01..06 uno a uno)
chmod +x scripts/*.sh scripts/pasos/*.sh
./scripts/01_deploy_all.sh

# 2. Ejecutar todas las comprobaciones de conectividad, servicios, balanceo y seguridad
./scripts/02_verify_all.sh

# 3. Escalar horizontalmente los servidores web (ejemplo a 5 replicas desde el nodo VNX terraform)
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform apply -auto-approve -var='web_replicas=5'"

# 4. Destruir la aplicacion y el escenario complementario (o anadir --full para apagar tambien K8s)
./scripts/03_destroy_all.sh
```
