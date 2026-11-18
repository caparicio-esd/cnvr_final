#!/bin/bash
# Prueba 5: Comprobar HTML personalizado y balanceo de carga via Ingress (/servers-G11)

echo "=== TEST 5: Personalizacion HTML y balanceo por Ingress (/servers-G11) ==="
for i in 1 2 3 4 5 6; do
  curl -s http://10.10.10.20/servers-G11 | grep "Pod (Servidor)"
done
