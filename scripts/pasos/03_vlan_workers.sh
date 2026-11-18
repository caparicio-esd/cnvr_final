#!/bin/bash
# Paso 3: Crear subinterfaces VLAN 1000 (e2.1000) y demonio DHCP CNI en los workers
set -e

echo "=== PASO 3: Configurar VLAN 1000 (e2.1000) y DHCP CNI en los workers ==="

# Worker 1: subir interfaz trunk e2, crear e2.1000 y lanzar /opt/cni/bin/dhcp daemon
ssh -o StrictHostKeyChecking=accept-new root@k8s-worker1 "ip link set e2 up"
ssh root@k8s-worker1 "ip link add link e2 name e2.1000 type vlan id 1000 || true"
ssh root@k8s-worker1 "ip link set e2.1000 up"
ssh -n root@k8s-worker1 "pkill -x dhcp || true; mkdir -p /run/cni && rm -f /run/cni/dhcp.sock && setsid /opt/cni/bin/dhcp daemon </dev/null >/var/log/cni-dhcp.log 2>&1 &"

# Worker 2: exactamente igual en e2.1000
ssh -o StrictHostKeyChecking=accept-new root@k8s-worker2 "ip link set e2 up"
ssh root@k8s-worker2 "ip link add link e2 name e2.1000 type vlan id 1000 || true"
ssh root@k8s-worker2 "ip link set e2.1000 up"
ssh -n root@k8s-worker2 "pkill -x dhcp || true; mkdir -p /run/cni && rm -f /run/cni/dhcp.sock && setsid /opt/cni/bin/dhcp daemon </dev/null >/var/log/cni-dhcp.log 2>&1 &"
