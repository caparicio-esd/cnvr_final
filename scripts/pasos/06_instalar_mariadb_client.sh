#!/bin/bash
# Paso 6: Instalar mariadb-client en Pod admin y Pods web via proxy HTTP de la VLAN
set -e

echo "=== PASO 6: Instalar mariadb-client en Pods via proxy VLAN (10.1.2.101:8888) ==="
# Se usa tinyproxy en LXC logs porque la NetworkPolicy default-deny-all bloquea Egress en eth0

kubectl exec admin -- bash -c 'sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" update && sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" install -y mariadb-client'

for POD in $(kubectl get pods -l app=web -o jsonpath='{.items[*].metadata.name}'); do
  kubectl exec "$POD" -- bash -c 'sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" update && sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::http::Proxy="http://10.1.2.101:8888" install -y mariadb-client'
done
