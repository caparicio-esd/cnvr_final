#!/bin/bash
# ==============================================================================
# Trabajo Final CNVR / ARSN (Curso 2026-27) - Grupo 11
# Script ensamblador de verificacion: ejecuta en orden las 6 baterias de prueba
# Autor: Carlos Aparicio de Santiago
# ==============================================================================

cd "$(dirname "$0")"

./pasos/test_01_recursos.sh
echo ""
./pasos/test_02_vlan_multus.sh
echo ""
./pasos/test_03_ssh.sh
echo ""
./pasos/test_04_bbdd_y_logs.sh
echo ""
./pasos/test_05_ingress_html.sh
echo ""
./pasos/test_06_networkpolicies.sh
