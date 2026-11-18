#!/bin/bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Script ensamblador de despliegue: ejecuta en orden los 6 pasos individuales
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

set -e
cd "$(dirname "$0")"

./pasos/01_claves_ssh.sh
./pasos/02_k8s_y_terraform_vm.sh
./pasos/03_vlan_workers.sh
./pasos/04_vnx_lxc.sh
./pasos/05_terraform_apply.sh
./pasos/06_instalar_mariadb_client.sh
