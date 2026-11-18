#!/usr/bin/env bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Script maestro de despliegue automatizado (entorno de laboratorio DIT-UPM)
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_DIR="${LAB_DIR:-/mnt/tmp/k8s_lab-calico-v02}"
WEB_REPLICAS="${WEB_REPLICAS:-3}"
VLAN_ID="${VLAN_ID:-1000}"

log() { printf "\n\033[1;34m[CNVR-DEPLOY]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m  [OK]\033[0m %s\n" "$*"; }

# ------------------------------------------------------------------------------
# 1. Generacion de los 2 pares de claves SSH independientes (Par 1 y Par 2)
# ------------------------------------------------------------------------------
log "1/6: Generando claves SSH en keys/..."
mkdir -p "${PROJECT_ROOT}/keys" "${PROJECT_ROOT}/vnx/conf/ssh"

[[ -f "${PROJECT_ROOT}/keys/id_rsa_internal" ]] || \
  ssh-keygen -q -t rsa -b 4096 -f "${PROJECT_ROOT}/keys/id_rsa_internal" -N "" -C "admin-to-vlan@cnvr-g11"
[[ -f "${PROJECT_ROOT}/keys/id_rsa_external" ]] || \
  ssh-keygen -q -t rsa -b 4096 -f "${PROJECT_ROOT}/keys/id_rsa_external" -N "" -C "host-to-admin@cnvr-g11"

chmod 600 "${PROJECT_ROOT}/keys/id_rsa_internal" "${PROJECT_ROOT}/keys/id_rsa_external"
cp "${PROJECT_ROOT}/keys/id_rsa_internal.pub" "${PROJECT_ROOT}/vnx/conf/ssh/authorized_keys"
ok "Claves SSH listas (keys/id_rsa_internal y keys/id_rsa_external)"

# ------------------------------------------------------------------------------
# 2. Arranque de Kubernetes Calico + nodo proveedor 'terraform' (Practica 1.4)
# ------------------------------------------------------------------------------
log "2/6: Arrancando cluster Kubernetes (Calico) y nodo VNX 'terraform'..."
if [[ ! -d "${LAB_DIR}" ]]; then
  (cd /mnt/tmp && /lab/cnvr/bin/get-k8s-calico)
fi

cd "${LAB_DIR}"
if ! kubectl get nodes >/dev/null 2>&1; then
  ./bin/start-k8s-calico
fi
./bin/get-master-kubeconf
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s || true

if ! ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new root@terraform "terraform --version" >/dev/null 2>&1; then
  sudo vnx -f k8s_lab-terraform.xml --create
  sudo vnx -f k8s_lab-terraform.xml -x install-terraform
fi
./bin/set-terraform-kubeconf
ok "Cluster K8s y nodo 'terraform' operativos"

# ------------------------------------------------------------------------------
# 3. Subinterfaces VLAN 802.1Q (e2.1000) y demonio CNI DHCP en los workers
# ------------------------------------------------------------------------------
log "3/6: Configurando VLAN ${VLAN_ID} y demonio CNI DHCP en k8s-worker1 y k8s-worker2..."
for WORKER in k8s-worker1 k8s-worker2; do
  ssh -o StrictHostKeyChecking=accept-new "root@${WORKER}" bash -s -- "${VLAN_ID}" <<'EOF'
    set -e
    VID="$1"
    ip link set e2 up
    ip link show "e2.${VID}" >/dev/null 2>&1 || ip link add link e2 name "e2.${VID}" type vlan id "${VID}"
    ip link set "e2.${VID}" up
    mkdir -p /run/cni
    pgrep -f '/opt/cni/bin/dhcp daemon' >/dev/null 2>&1 || nohup /opt/cni/bin/dhcp daemon >/var/log/cni-dhcp.log 2>&1 &
EOF
done
ok "Subinterfaces e2.${VLAN_ID} y /run/cni/dhcp.sock activos en ambos workers"

# ------------------------------------------------------------------------------
# 4. Despliegue del escenario VNX complementario (LXC bbdd y logs en VLAN 1000)
# ------------------------------------------------------------------------------
log "4/6: Desplegando contenedores LXC 'bbdd' y 'logs' en VNX..."
VNX_DIR="${PROJECT_ROOT}/vnx"
if [[ ! -e /usr/share/vnx/filesystems/rootfs_lxc_ubuntu64 ]] && [[ -f "${LAB_DIR}/k8s_lab-vms-vlan.xml" ]]; then
  LAB_ROOTFS="$(sed -n 's|.*<filesystem[^>]*>\(.*rootfs_lxc[^<]*\)</filesystem>.*|\1|p' "${LAB_DIR}/k8s_lab-vms-vlan.xml" | head -n 1)"
  [[ "${LAB_ROOTFS}" = /* ]] || LAB_ROOTFS="${LAB_DIR}/${LAB_ROOTFS}"
  VNX_DIR="/mnt/tmp/cnvr_vnx_lxc"
  rm -rf "${VNX_DIR}" && cp -r "${PROJECT_ROOT}/vnx" "${VNX_DIR}"
  sed -i "s|/usr/share/vnx/filesystems/rootfs_lxc_ubuntu64|${LAB_ROOTFS}|g" "${VNX_DIR}/k8s_lxc_vlan.xml"
fi

cd "${VNX_DIR}"
sudo lxc-ls --active | grep -qw "bbdd" || sudo vnx -f k8s_lxc_vlan.xml -v --create
sudo vnx -f k8s_lxc_vlan.xml -v -x setup
ok "Contenedores LXC 'bbdd' (10.1.2.100) y 'logs' (10.1.2.101) configurados"

# ------------------------------------------------------------------------------
# 5. Orquestacion declarativa en Kubernetes con Terraform (via /shared)
# ------------------------------------------------------------------------------
log "5/6: Sincronizando plantilla HCL en /shared y aplicando Terraform..."
SHARED_PROJECT="${LAB_DIR}/shared/cnvr_final"
mkdir -p "${SHARED_PROJECT}/terraform" "${SHARED_PROJECT}/keys"
cp -f "${PROJECT_ROOT}/terraform/"*.tf "${PROJECT_ROOT}/terraform/terraform.tfvars" "${SHARED_PROJECT}/terraform/"
cp -f "${PROJECT_ROOT}/keys/"* "${SHARED_PROJECT}/keys/"
chmod 600 "${SHARED_PROJECT}/keys/id_rsa_internal" "${SHARED_PROJECT}/keys/id_rsa_external"

ssh root@terraform "cd /shared/cnvr_final/terraform && terraform init && terraform validate && terraform apply -auto-approve -var='web_replicas=${WEB_REPLICAS}'"
cp -f "${SHARED_PROJECT}/terraform/terraform.tfstate" "${PROJECT_ROOT}/terraform/terraform.tfstate" 2>/dev/null || true

kubectl rollout status deployment/web-deployment --timeout=180s
kubectl wait --for=condition=Ready pod/admin --timeout=120s
ok "Recursos Kubernetes desplegados por Terraform"

# ------------------------------------------------------------------------------
# 6. Cliente MariaDB en los Pods (usando tinyproxy de la VLAN por bloqueo Egress)
# ------------------------------------------------------------------------------
log "6/6: Instalando mariadb-client en Pod admin y Pods web..."
INSTALL_MARIADB='export DEBIAN_FRONTEND=noninteractive; sudo apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" update -qq && sudo apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" install -y -qq mariadb-client >/dev/null'

kubectl exec admin -- bash -c "${INSTALL_MARIADB}"
for POD in $(kubectl get pods -l app=web -o jsonpath='{.items[*].metadata.name}'); do
  kubectl exec "${POD}" -- bash -c "${INSTALL_MARIADB}"
done
ok "Despliegue completado con exito"

ssh root@terraform "cd /shared/cnvr_final/terraform && terraform output"
