#!/bin/bash
# Paso 5: Copiar ficheros Terraform + claves a /shared y ejecutar Terraform en su nodo VNX
set -e

PROYECTO_DIR=$(cd "$(dirname "$0")/../.." && pwd)
LAB_DIR="/mnt/tmp/k8s_lab-calico-v02"

echo "=== PASO 5: Sincronizar Terraform en /shared y desplegar en Kubernetes ==="
mkdir -p "$LAB_DIR/shared/cnvr_final/terraform"
mkdir -p "$LAB_DIR/shared/cnvr_final/keys"

cp "$PROYECTO_DIR/terraform/"*.tf "$LAB_DIR/shared/cnvr_final/terraform/"
cp "$PROYECTO_DIR/terraform/terraform.tfvars" "$LAB_DIR/shared/cnvr_final/terraform/"
cp "$PROYECTO_DIR/keys/"* "$LAB_DIR/shared/cnvr_final/keys/"
chmod 600 "$LAB_DIR/shared/cnvr_final/keys/id_rsa_internal"
chmod 600 "$LAB_DIR/shared/cnvr_final/keys/id_rsa_external"

# Ciclo estandar de Terraform dentro del nodo 'terraform' (Practica 1.4)
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform init"
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform validate"
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform apply -auto-approve"

# Esperar a que las 3 replicas web y el Pod admin completen sus initContainers
kubectl rollout status deployment/web-deployment --timeout=180s
kubectl wait --for=condition=Ready pod/admin --timeout=120s

echo "=== Salidas (outputs) de Terraform ==="
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform output"
