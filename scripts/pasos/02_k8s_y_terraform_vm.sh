#!/bin/bash
# Paso 2: Arrancar escenario Kubernetes (Calico) y nodo VNX 'terraform' (Practica 1.4)
set -e

LAB_DIR="/mnt/tmp/k8s_lab-calico-v02"

echo "=== PASO 2: Arrancar cluster Kubernetes (Calico) y nodo Terraform ==="
if [ ! -d "$LAB_DIR" ]; then
  cd /mnt/tmp
  /lab/cnvr/bin/get-k8s-calico
fi

cd "$LAB_DIR"
if ! kubectl get nodes >/dev/null 2>&1; then
  ./bin/start-k8s-calico
fi
./bin/get-master-kubeconf

# Esperar a que los 3 nodos y el controlador ingress-nginx esten Ready
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s

# Arrancar la VM VNX 'terraform' (10.10.10.13), instalar Terraform y pasar kubeconfig
if ! ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=accept-new root@terraform true 2>/dev/null; then
  sudo vnx -f k8s_lab-terraform.xml --create
  sudo vnx -f k8s_lab-terraform.xml -x install-terraform
fi
./bin/set-terraform-kubeconf
