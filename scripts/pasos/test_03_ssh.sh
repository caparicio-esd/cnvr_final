#!/bin/bash
# Prueba 3: Comprobar acceso SSH por claves (Par 2 exterior y Par 1 interno)

PROYECTO_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$PROYECTO_DIR"

WEB_POD_1=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
WEB_VLAN_IP_1=$(kubectl exec "$WEB_POD_1" -- ip -4 addr show dev net1 | awk '/inet / {print $2}' | cut -d/ -f1)

echo "=== TEST 3: Acceso SSH sin contrasena (Par 2 exterior y Par 1 interno) ==="
# 3a. Exterior (Host user_LAN) -> Pod admin por NodePort 30022 en k8s-worker1
ssh -i keys/id_rsa_external -p 30022 -o StrictHostKeyChecking=accept-new adminuser@10.10.10.11 "hostname && id"

# 3b. Interior (Pod admin) -> servidor web, LXC bbdd y LXC logs por VLAN 1000
kubectl exec admin -- su - adminuser -c "ssh webuser@${WEB_VLAN_IP_1} hostname"
kubectl exec admin -- su - adminuser -c "ssh adminuser@10.1.2.100 hostname"
kubectl exec admin -- su - adminuser -c "ssh adminuser@10.1.2.101 hostname"
