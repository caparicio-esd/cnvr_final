#!/usr/bin/env bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Suite automatizada de verificacion integral del escenario:
#   1. Estado de recursos en Kubernetes y VNX
#   2. Interfaces secundarias Multus y conectividad ICMP en la VLAN 1000
#   3. Acceso SSH sin contrasena (Host -> Admin y Admin -> Web / BBDD / Logs)
#   4. Administracion remota de MariaDB (3306) y Rsyslog (514) desde Pods
#   5. Personalizacion HTML (ConfigMap + initContainer) y balanceo por Ingress
#   6. Auditoria de seguridad de las 3 NetworkPolicies (pruebas + y -)
#
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GRUPO="${GRUPO:-11}"
ADMIN_WORKER_IP="${ADMIN_WORKER_IP:-10.10.10.11}"
ADMIN_NODE_PORT="${ADMIN_NODE_PORT:-30022}"
INGRESS_IP="${INGRESS_IP:-10.10.10.20}"
BBDD_VLAN_IP="${BBDD_VLAN_IP:-10.1.2.100}"
LOGS_VLAN_IP="${LOGS_VLAN_IP:-10.1.2.101}"
ADMIN_VLAN_IP="${ADMIN_VLAN_IP:-10.1.2.10}"

PASS_COUNT=0
FAIL_COUNT=0

banner() { printf "\n\033[1;36m======================================================================\n %s\n======================================================================\033[0m\n" "$*"; }
pass()   { PASS_COUNT=$((PASS_COUNT + 1)); printf "\033[1;32m  [PASS]\033[0m %s\n" "$*"; }
fail()   { FAIL_COUNT=$((FAIL_COUNT + 1)); printf "\033[1;31m  [FAIL]\033[0m %s\n" "$*"; }

DETECTED_INGRESS_IP="$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
[[ -n "${DETECTED_INGRESS_IP}" ]] && INGRESS_IP="${DETECTED_INGRESS_IP}"

# ------------------------------------------------------------------------------
# BLOQUE 1: Recursos desplegados por Terraform en Kubernetes
# ------------------------------------------------------------------------------
banner "1. Estado de Pods, Secrets, ConfigMap, NADs, Services, Ingress y NetworkPolicies"
kubectl get pods -o wide --show-labels
echo ""
kubectl get secrets,configmap,svc,ingress,networkpolicy
echo ""
kubectl get net-attach-def
echo ""
ssh -o ConnectTimeout=3 root@terraform "cd /shared/cnvr_final/terraform && terraform state list && echo '' && terraform output" 2>/dev/null || true

WEB_READY="$(kubectl get pods -l app=web --no-headers 2>/dev/null | grep -c 'Running' || true)"
if [[ "${WEB_READY}" -ge 3 ]]; then
  pass "Deployment web operativo con ${WEB_READY} Pods en ejecucion"
else
  fail "Se esperaban al menos 3 Pods web Running (encontrados: ${WEB_READY})"
fi

ADMIN_NODE_ACTUAL="$(kubectl get pod admin -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
if [[ "${ADMIN_NODE_ACTUAL}" == "k8s-worker1" ]]; then
  pass "Pod admin desplegado en k8s-worker1 mediante nodeSelector"
else
  fail "Pod admin en nodo inesperado: ${ADMIN_NODE_ACTUAL}"
fi

# ------------------------------------------------------------------------------
# BLOQUE 2: Interfaces Multus (net1) y conectividad en la VLAN compartida
# ------------------------------------------------------------------------------
banner "2. Interfaces Multus (net1) y conectividad L2 en VLAN 1000"

ADMIN_NET1="$(kubectl exec admin -- ip -4 -o addr show dev net1 | awk '{print $4}')"
echo "  Pod admin      -> net1: ${ADMIN_NET1}"

declare -a WEB_VLAN_IPS=()
for POD in $(kubectl get pods -l app=web -o jsonpath='{.items[*].metadata.name}'); do
  WIP="$(kubectl exec "${POD}" -- ip -4 -o addr show dev net1 | awk '{split($4,a,"/"); print a[1]}')"
  WEB_VLAN_IPS+=("${WIP}")
  echo "  Pod ${POD} -> net1: ${WIP}/24"
done

for TARGET in "${BBDD_VLAN_IP}" "${LOGS_VLAN_IP}" "${WEB_VLAN_IPS[@]}"; do
  if kubectl exec admin -- ping -c 2 -W 2 "${TARGET}" >/dev/null 2>&1; then
    pass "Ping VLAN desde Pod admin (${ADMIN_VLAN_IP}) -> ${TARGET} correcto"
  else
    fail "Fallo de ping VLAN desde Pod admin -> ${TARGET}"
  fi
done

# ------------------------------------------------------------------------------
# BLOQUE 3: Autenticacion SSH por clave publica/privada (sin contrasena)
# ------------------------------------------------------------------------------
banner "3. Verificacion de acceso SSH mediante pares de claves independientes"

# 3a. Exterior (Host en user_LAN) -> Pod admin via NodePort en k8s-worker1
if ssh -i "${PROJECT_ROOT}/keys/id_rsa_external" \
       -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
       -p "${ADMIN_NODE_PORT}" "adminuser@${ADMIN_WORKER_IP}" "hostname && id" ; then
  pass "SSH exterior -> Pod admin (${ADMIN_WORKER_IP}:${ADMIN_NODE_PORT}) con Par 2 exitoso"
else
  fail "Fallo SSH exterior -> Pod admin (${ADMIN_WORKER_IP}:${ADMIN_NODE_PORT})"
fi

# 3b. Pod admin -> cada Pod web en la VLAN con Par 1 (montado desde Secret)
for WIP in "${WEB_VLAN_IPS[@]}"; do
  REMOTE_HOST="$(kubectl exec admin -- su - adminuser -c "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new webuser@${WIP} hostname" 2>/dev/null || true)"
  if [[ -n "${REMOTE_HOST}" ]]; then
    pass "SSH interno desde Pod admin -> servidor web (${WIP} = ${REMOTE_HOST}) con Par 1 exitoso"
  else
    fail "Fallo SSH interno desde Pod admin -> servidor web (${WIP})"
  fi
done

# 3c. Pod admin -> contenedores LXC bbdd y logs en VNX
for LXC_IP in "${BBDD_VLAN_IP}" "${LOGS_VLAN_IP}"; do
  LXC_HOST="$(kubectl exec admin -- su - adminuser -c "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new adminuser@${LXC_IP} hostname" 2>/dev/null || true)"
  if [[ -n "${LXC_HOST}" ]]; then
    pass "SSH interno desde Pod admin -> contenedor LXC '${LXC_HOST}' (${LXC_IP}) exitoso"
  else
    fail "Fallo SSH interno desde Pod admin -> contenedor LXC (${LXC_IP})"
  fi
done

# ------------------------------------------------------------------------------
# BLOQUE 4: Administracion de MariaDB y Servidor de Logs desde Pods K8s
# ------------------------------------------------------------------------------
banner "4. Administracion de Base de Datos MariaDB y Servidor de Logs sobre VLAN"

if kubectl exec admin -- mariadb -h "${BBDD_VLAN_IP}" -u dbadmin -pcnvr2026 cnvr_db -e "SELECT * FROM nodos_registrados;"; then
  pass "Consulta administrativa a MariaDB (${BBDD_VLAN_IP}:3306) desde Pod admin exitosa"
else
  fail "Fallo de conexion a MariaDB desde Pod admin"
fi

FIRST_WEB_POD="$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')"
FIRST_WEB_VLAN="${WEB_VLAN_IPS[0]}"
if kubectl exec "${FIRST_WEB_POD}" -- mariadb -h "${BBDD_VLAN_IP}" -u dbadmin -pcnvr2026 cnvr_db \
     -e "INSERT INTO nodos_registrados (nombre, rol, ip_vlan) VALUES ('${FIRST_WEB_POD}', 'Pod Web Nginx', '${FIRST_WEB_VLAN}'); SELECT * FROM nodos_registrados;"; then
  pass "Escritura y lectura en MariaDB desde servidor web (${FIRST_WEB_POD}) exitosa"
else
  fail "Fallo de administracion de MariaDB desde servidor web (${FIRST_WEB_POD})"
fi

# Envio de evento syslog por UDP 514 al contenedor LXC logs
LOG_TAG="cnvr-test-$(date +%s)"
kubectl exec admin -- bash -c "echo '<14>${LOG_TAG}: Prueba de log remoto desde Pod admin' > /dev/udp/${LOGS_VLAN_IP}/514" || true
sleep 1
if kubectl exec admin -- su - adminuser -c "ssh -o BatchMode=yes adminuser@${LOGS_VLAN_IP} 'sudo grep -rn \"${LOG_TAG}\" /var/log/remotos /var/log/syslog 2>/dev/null'" | grep -q "${LOG_TAG}"; then
  pass "Recepcion centralizada de logs en LXC 'logs' (${LOGS_VLAN_IP}:514) verificada"
else
  fail "No se encontro el mensaje de prueba en el servidor de logs (${LOGS_VLAN_IP})"
fi

# ------------------------------------------------------------------------------
# BLOQUE 5: Ingress (/servers-GX), plantilla HTML personalizada y balanceo
# ------------------------------------------------------------------------------
banner "5. Acceso HTTP por Ingress (/servers-G${GRUPO}) y balanceo entre Pods"

INGRESS_URL="http://${INGRESS_IP}/servers-G${GRUPO}"
declare -A SEEN_PODS=()
for i in {1..9}; do
  RESP_POD="$(curl -fsSL --max-time 5 "${INGRESS_URL}" | sed -n 's/.*Pod (Servidor):<\/span> <span class="val">\([^<]*\)<.*/\1/p')"
  if [[ -n "${RESP_POD}" ]]; then
    SEEN_PODS["${RESP_POD}"]=1
    echo "  Peticion #${i} a ${INGRESS_URL} -> Atendida por Pod: ${RESP_POD}"
  fi
done

if [[ "${#SEEN_PODS[@]}" -ge 2 ]]; then
  pass "Ingress operativo y balanceando carga entre multiples Pods (${!SEEN_PODS[*]})"
else
  fail "El Ingress no devolvio respuestas balanceadas de distintos Pods"
fi

# ------------------------------------------------------------------------------
# BLOQUE 6: Auditoria de las 3 NetworkPolicies (aislamiento Calico en eth0)
# ------------------------------------------------------------------------------
banner "6. Comprobacion de aislamiento por NetworkPolicies (Calico)"

# 6a. Egress bloqueado por default-deny-all en eth0 hacia Internet
if kubectl exec admin -- curl -fsSL --max-time 3 http://1.1.1.1 >/dev/null 2>&1; then
  fail "Egress hacia Internet NO fue bloqueado en Pod admin (revisar default-deny-all)"
else
  pass "Default-Deny Egress activo: trafico desde Pod admin hacia Internet en eth0 bloqueado"
fi

# 6b. Acceso HTTP directo desde Pod admin a IP Calico (eth0) de un Pod web bloqueado
FIRST_WEB_CALICO_IP="$(kubectl get pod "${FIRST_WEB_POD}" -o jsonpath='{.status.podIP}')"
if kubectl exec admin -- curl -fsSL --max-time 3 "http://${FIRST_WEB_CALICO_IP}:80" >/dev/null 2>&1; then
  fail "El Pod admin pudo acceder por eth0 al puerto 80 del Pod web (solo ingress-nginx debe poder)"
else
  pass "allow-ingress-to-web activo: acceso HTTP directo desde otro Pod a ${FIRST_WEB_CALICO_IP}:80 bloqueado"
fi

# 6c. Acceso SSH a admin desde una IP NO autorizada (p.ej. k8s-master 10.10.10.10 != 10.10.20.2) bloqueado
if ssh -o StrictHostKeyChecking=accept-new root@k8s-master \
     "nc -zv -w 3 ${ADMIN_WORKER_IP} ${ADMIN_NODE_PORT}" >/dev/null 2>&1; then
  fail "Conexion TCP al NodePort de admin permitida desde k8s-master (10.10.10.10), fuera del ipBlock"
else
  pass "allow-ssh-to-admin + externalTrafficPolicy:Local activos: acceso SSH desde IP no autorizada (10.10.10.10) bloqueado"
fi

banner "RESUMEN FINAL: ${PASS_COUNT} pruebas superadas | ${FAIL_COUNT} fallos"
[[ "${FAIL_COUNT}" -eq 0 ]]
