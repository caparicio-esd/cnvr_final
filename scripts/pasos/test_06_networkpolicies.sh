#!/bin/bash
# Prueba 6: Auditoria de aislamiento de las NetworkPolicies (bloqueos esperados)

WEB_POD_1=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
WEB_CALICO_IP_1=$(kubectl get pod "$WEB_POD_1" -o jsonpath='{.status.podIP}')

echo "=== TEST 6: Pruebas de bloqueo de las NetworkPolicies (Calico) ==="
echo "--- 6a. Egress hacia Internet desde Pod admin (debe fallar/timeout) ---"
kubectl exec admin -- curl -s --max-time 3 http://1.1.1.1 || echo "[OK] Salida a Internet bloqueada por default-deny-all"

echo "--- 6b. HTTP directo a Pod web por eth0 desde admin (debe fallar/timeout) ---"
kubectl exec admin -- curl -s --max-time 3 "http://${WEB_CALICO_IP_1}:80" || echo "[OK] Acceso directo bloqueado por allow-ingress-to-web"

echo "--- 6c. SSH al NodePort desde IP no autorizada k8s-master 10.10.10.10 ---"
ssh -o StrictHostKeyChecking=accept-new root@k8s-master "nc -zv -w 3 10.10.10.11 30022" || echo "[OK] SSH desde 10.10.10.10 bloqueado por allow-ssh-to-admin + Local"
