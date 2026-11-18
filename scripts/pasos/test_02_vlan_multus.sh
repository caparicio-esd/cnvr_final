#!/bin/bash
# Prueba 2: Comprobar interfaces Multus (net1) y conectividad ICMP en la VLAN 1000

echo "=== TEST 2: Interfaces Multus (net1) y pings en VLAN 1000 ==="
echo "--- Pod admin (IP estatica 10.1.2.10/24) ---"
kubectl exec admin -- ip -4 addr show dev net1

echo "--- Pods web (IP dinamica DHCP 10.1.2.50-95) ---"
for POD in $(kubectl get pods -l app=web -o jsonpath='{.items[*].metadata.name}'); do
  echo "Pod $POD:"
  kubectl exec "$POD" -- ip -4 -o addr show dev net1
done

# Tomamos la IP VLAN del primer Pod web para probar conectividad con admin
WEB_POD_1=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
WEB_VLAN_IP_1=$(kubectl exec "$WEB_POD_1" -- ip -4 addr show dev net1 | awk '/inet / {print $2}' | cut -d/ -f1)

echo "--- Pings desde admin hacia Pod web ($WEB_VLAN_IP_1), bbdd (10.1.2.100) y logs (10.1.2.101) ---"
kubectl exec admin -- ping -c 2 "$WEB_VLAN_IP_1"
kubectl exec admin -- ping -c 2 10.1.2.100
kubectl exec admin -- ping -c 2 10.1.2.101
