#!/bin/bash
# Paso 1: Generar los 2 pares de claves SSH independientes (Par 1 interno y Par 2 externo)
set -e

PROYECTO_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$PROYECTO_DIR"

echo "=== PASO 1: Generar los dos pares de claves SSH en keys/ ==="
mkdir -p keys vnx/conf/ssh

# Par 1: Pod admin -> Pods web y contenedores LXC (bbdd y logs)
if [ ! -f keys/id_rsa_internal ]; then
  ssh-keygen -t rsa -b 4096 -f keys/id_rsa_internal -N ""
fi

# Par 2: Host exterior (user_LAN) -> Pod admin (NodePort)
if [ ! -f keys/id_rsa_external ]; then
  ssh-keygen -t rsa -b 4096 -f keys/id_rsa_external -N ""
fi

# Copiar la clave publica interna para inyectarla en los LXC con <filetree> de VNX
cp keys/id_rsa_internal.pub vnx/conf/ssh/authorized_keys
