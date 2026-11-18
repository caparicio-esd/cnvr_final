#!/bin/bash
# Prueba 4: Administrar MariaDB (bbdd) y enviar logs a Rsyslog (logs) desde los Pods

WEB_POD_1=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
WEB_VLAN_IP_1=$(kubectl exec "$WEB_POD_1" -- ip -4 addr show dev net1 | awk '/inet / {print $2}' | cut -d/ -f1)

echo "=== TEST 4: MariaDB (10.1.2.100:3306) y Rsyslog (10.1.2.101:514) ==="
kubectl exec admin -- mariadb -h 10.1.2.100 -u dbadmin -pcnvr2026 cnvr_db -e "SELECT * FROM nodos_registrados;"

kubectl exec "$WEB_POD_1" -- mariadb -h 10.1.2.100 -u dbadmin -pcnvr2026 cnvr_db \
  -e "INSERT INTO nodos_registrados (nombre, rol, ip_vlan) VALUES ('${WEB_POD_1}', 'Pod Web Nginx', '${WEB_VLAN_IP_1}'); SELECT * FROM nodos_registrados;"

# Envio de log por UDP/514 usando /dev/udp de bash y comprobacion en el LXC logs
kubectl exec admin -- bash -c "echo '<14>cnvr-test: Prueba de log desde Pod admin' > /dev/udp/10.1.2.101/514"
sleep 1
kubectl exec admin -- su - adminuser -c "ssh adminuser@10.1.2.101 'sudo grep -rn cnvr-test /var/log/remotos /var/log/syslog'"
