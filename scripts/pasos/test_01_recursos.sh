#!/bin/bash
# Prueba 1: Listar recursos desplegados en Kubernetes y estado en Terraform

echo "=== TEST 1: Recursos desplegados en Kubernetes y Terraform ==="
kubectl get pods -o wide --show-labels
kubectl get secrets,configmap,svc,ingress,networkpolicy
kubectl get net-attach-def
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform state list"
ssh root@terraform "cd /shared/cnvr_final/terraform && terraform output"
