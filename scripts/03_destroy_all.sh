#!/bin/bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Script de destruccion ordenada del escenario (usar --full para apagar VMs K8s)
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

set -e

cd "$(dirname "$0")/.."
PROYECTO_DIR="$(pwd)"
LAB_DIR="/mnt/tmp/k8s_lab-calico-v02"

echo "=== 1. Destruir recursos Kubernetes con Terraform ==="
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform destroy -auto-approve" || true

echo "=== 2. Destruir contenedores LXC 'bbdd' y 'logs' en VNX ==="
cd "$PROYECTO_DIR/vnx"
sudo vnx -f k8s_lxc_vlan.xml -v --destroy || true

echo "=== 3. Eliminar subinterfaces e2.1000 y demonio DHCP en workers ==="
ssh root@k8s-worker1 "ip link del e2.1000 2>/dev/null || true; systemctl stop cnvr-cni-dhcp 2>/dev/null || true; pkill -x dhcp || true"
ssh root@k8s-worker2 "ip link del e2.1000 2>/dev/null || true; systemctl stop cnvr-cni-dhcp 2>/dev/null || true; pkill -x dhcp || true"

if [ "$1" = "--full" ]; then
  echo "=== 4. Apagar nodo 'terraform' y cluster Kubernetes (--full) ==="
  cd "$LAB_DIR"
  sudo vnx -f k8s_lab-terraform.xml --destroy || true
  ./bin/stop-k8s-calico || true
fi

echo "=== Limpieza completada ==="
