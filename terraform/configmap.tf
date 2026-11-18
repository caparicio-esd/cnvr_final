# ==============================================================================
# Apartado 3.1: ConfigMap con la plantilla HTML personalizada
# Incluye marcadores dinamicos (__POD_NAME__, __NODE_NAME__, __POD_IP__, __GROUP_NUMBER__)
# que son sustituidos en tiempo de inicializacion por el initContainer de cada Pod.
# ==============================================================================

resource "kubernetes_config_map_v1" "web_html_template" {
  metadata {
    name      = "web-html-template"
    namespace = var.namespace
    labels = {
      app        = "web"
      managed-by = "terraform"
    }
  }

  data = {
    "index.html" = <<-EOT
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CNVR/ARSN - Grupo __GROUP_NUMBER__ | __POD_NAME__</title>
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
          .card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 2rem 2.5rem; max-width: 560px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.4); }
          .badge { display: inline-block; background: #0284c7; color: #fff; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; margin-bottom: 1rem; }
          h1 { margin: 0 0 0.75rem 0; font-size: 1.5rem; color: #38bdf8; }
          .meta { background: #0f172a; border-radius: 8px; padding: 1rem; font-family: monospace; font-size: 0.95rem; line-height: 1.7; border: 1px solid #1e293b; }
          .key { color: #94a3b8; }
          .val { color: #4ade80; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="card">
          <span class="badge">CNVR / ARSN 2026-27 &middot; Grupo G__GROUP_NUMBER__</span>
          <h1>Aplicaci&oacute;n Web Escalable en Kubernetes</h1>
          <p>Respuesta servida din&aacute;micamente a trav&eacute;s de Ingress NGINX y balanceada por Service ClusterIP:</p>
          <div class="meta">
            <div><span class="key">Pod (Servidor):</span> <span class="val">__POD_NAME__</span></div>
            <div><span class="key">Nodo Worker:   </span> <span class="val">__NODE_NAME__</span></div>
            <div><span class="key">IP CNI Calico: </span> <span class="val">__POD_IP__</span></div>
            <div><span class="key">Ruta Ingress:  </span> <span class="val">/servers-G__GROUP_NUMBER__</span></div>
          </div>
        </div>
      </body>
      </html>
    EOT
  }
}
