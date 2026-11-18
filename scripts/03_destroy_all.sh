#!/usr/bin/env bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Script de destruccion y limpieza ordenada del escenario
#   Sin argumentos: destruye recursos K8s (Terraform), LXC VNX y subinterfaces VLAN
#   Con --full:     apaga tambien el nodo 'terraform' y el cluster K8s Calico
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_DIR="${LAB_DIR:-/mnt/tmp/k8s_lab-calico-v02}"
VLAN_ID="${VLAN_ID:-1000}"

log() { printf "\n\033[1;34m[CNVR-DESTROY]\033[0m %s\n" "$*"; }

log "1/4: Destruyendo recursos Kubernetes desde Terraform (/shared)..."
ssh -o ConnectTimeout=3 root@terraform \
  "cd /shared/cnvr_final/terraform && terraform destroy -auto-approve" 2>/dev/null || true
rm -f "${PROJECT_ROOT}/terraform/terraform.tfstate"*

log "2/4: Destruyendo contenedores LXC 'bbdd' y 'logs'..."
VNX_DIR="${PROJECT_ROOT}/vnx"
[[ -f "/mnt/tmp/cnvr_vnx_lxc/k8s_lxc_vlan.xml" ]] && VNX_DIR="/mnt/tmp/cnvr_vnx_lxc"
(cd "${VNX_DIR}" && sudo vnx -f k8s_lxc_vlan.xml -v --destroy || true)
rm -rf /mnt/tmp/cnvr_vnx_lxc

log "3/4: Eliminando subinterfaces e2.${VLAN_ID} y demonio DHCP en workers..."
for WORKER in k8s-worker1 k8s-worker2; do
  ssh -o ConnectTimeout=3 "root@${WORKER}" \
    "ip link del e2.${VLAN_ID} 2>/dev/null || true; pkill -f '/opt/cni/bin/dhcp daemon' 2>/dev/null || true; rm -f /run/cni/dhcp.sock" || true
done

if [[ "${1:-}" == "--full" ]]; then
  log "4/4: Apagando nodo 'terraform' y cluster Kubernetes Calico (--full)..."
  cd "${LAB_DIR}"
  sudo vnx -f k8s_lab-terraform.xml --destroy || true
  ./bin/stop-k8s-calico || true
else
  log "4/4: Cluster Kubernetes y nodo 'terraform' conservados activos (usa '--full' para apagarlos)."
fi

log "Limpieza completada."
