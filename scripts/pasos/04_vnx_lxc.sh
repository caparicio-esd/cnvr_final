#!/bin/bash
# Paso 4: Desplegar los contenedores LXC 'bbdd' y 'logs' en VNX sobre VLAN 1000
set -e

PROYECTO_DIR=$(cd "$(dirname "$0")/../.." && pwd)

echo "=== PASO 4: Desplegar contenedores LXC 'bbdd' y 'logs' en VNX ==="
# (Si el rootfs LXC de tu PC tuviera otra ruta, ajustarla en vnx/k8s_lxc_vlan.xml)
cd "$PROYECTO_DIR/vnx"
sudo vnx -f k8s_lxc_vlan.xml -v --create
sudo vnx -f k8s_lxc_vlan.xml -v -x setup
