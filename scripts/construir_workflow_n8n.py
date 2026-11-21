"""
Construye automatizacion/n8n_plan_semanal_emy.json (flujo n8n importable).
Se genera con código para garantizar un JSON válido; el archivo resultante es el que
se importa en n8n (Workflows > Import from file).  Uso: python3 scripts/construir_workflow_n8n.py
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "automatizacion" / "n8n_plan_semanal_emy.json"

CD = "cd \"{{ $('Configuración').first().json.repo_path }}\" && "

CODE_JS = r"""// BPMN: "Publicar hoja de ruta y orden de carga" (lane SIG)
// Convierte el JSON entregado por SQLite en un correo HTML legible en el celular.
const data = JSON.parse($input.first().json.stdout);
const pct = (a, b) => Math.round(100 * a / b);
let html = `<h2>Plan semanal Alimentos Emy</h2><p>Generado: ${data.generado}</p>`;
for (const p of data.planes) {
  html += `<h3>${p.ruta} · ${p.fecha}</h3>`;
  html += `<p><b>Carga:</b> ${p.kg_plan} kg de ${p.capacidad_kg} kg (${pct(p.kg_plan, p.capacidad_kg)} % del furgón)</p>`;
  html += '<table border="1" cellpadding="4" cellspacing="0"><tr><th>Familia</th><th>Unidades</th><th>kg</th></tr>';
  html += p.carga.map(c => `<tr><td>${c.familia}</td><td align="right">${c.unidades}</td><td align="right">${c.kg}</td></tr>`).join('');
  html += '</table><p><b>Orden de visita:</b></p><ol>';
  html += p.visitas.map(v => `<li>${v.cliente} · ${v.nombre}</li>`).join('');
  html += '</ol>';
}
if (data.alertas.length) {
  html += `<h3>Clientes con caída de frecuencia (${data.alertas.length})</h3><ul>`;
  html += data.alertas.map(a => `<li>${a.cliente} (${a.zona}): ${a.compras_sem_hist} → ${a.compras_sem_rec} compras/semana</li>`).join('');
  html += '</ul>';
}
const asunto = `Plan semanal de rutas y carga · ${data.planes.length} rutas` +
               (data.alertas.length ? ` · ${data.alertas.length} alertas de clientes` : '');
return [{ json: { asunto, html, n_planes: data.planes.length, n_alertas: data.alertas.length } }];
"""


def node(id_, name, type_, version, pos, params, **extra):
    n = {"parameters": params, "id": id_, "name": name, "type": type_,
         "typeVersion": version, "position": pos}
    n.update(extra)
    return n


nodes = [
    node("a1b2c3d4-0001-4000-8000-000000000001", "Domingo 19:00", "n8n-nodes-base.scheduleTrigger", 1.2,
         [0, 0], {"rule": {"interval": [{"field": "weeks", "weeksInterval": 1, "triggerAtDay": [0],
                                         "triggerAtHour": 19, "triggerAtMinute": 0}]}},
         notes="BPMN: evento de inicio temporizador 'Domingo 19:00 (inicio de planificación semanal)'"),
    node("a1b2c3d4-0001-4000-8000-000000000002", "Ejecutar ahora (demo)", "n8n-nodes-base.manualTrigger", 1,
         [0, 200], {}),
    node("a1b2c3d4-0001-4000-8000-000000000003", "Configuración", "n8n-nodes-base.set", 3.4,
         [240, 100], {"assignments": {"assignments": [
             {"id": "cfg-1", "name": "repo_path", "value": "/RUTA/A/ICN292-Proyecto", "type": "string"},
             {"id": "cfg-2", "name": "correo_destino", "value": "correo-del-dueno@ejemplo.cl", "type": "string"}]},
             "options": {}},
         notes="Editar repo_path (carpeta del repositorio clonado) y correo_destino antes de activar"),
    node("a1b2c3d4-0001-4000-8000-000000000004", "Importar ventas Bicom (RF1)", "n8n-nodes-base.executeCommand", 1,
         [480, 100], {"command": "=" + CD +
                      "if [ -f data/entrada/export_bicom.csv ]; then "
                      "sqlite3 db/alimentos_emy.db < db/procesos/importar_ventas_bicom.sql && "
                      "mkdir -p data/entrada/procesados && "
                      "mv data/entrada/export_bicom.csv data/entrada/procesados/export_$(date +%Y%m%d_%H%M).csv; "
                      "else echo 'Sin exportación nueva de Bicom: se planifica con la historia existente'; fi"},
         notes="BPMN: tarea de servicio 'Importar ventas exportadas desde Bicom'"),
    node("a1b2c3d4-0001-4000-8000-000000000005", "Generar plan y alertas (RF2-RF6, RF9)",
         "n8n-nodes-base.executeCommand", 1, [720, 100],
         {"command": "=" + CD + "sqlite3 db/alimentos_emy.db < db/procesos/generar_plan_semanal.sql"},
         notes="BPMN: 'Calcular demanda', 'Seleccionar clientes', 'Generar plan de carga', 'Detectar caída de frecuencia'"),
    node("a1b2c3d4-0001-4000-8000-000000000006", "Leer plan en JSON", "n8n-nodes-base.executeCommand", 1,
         [960, 100], {"command": "=" + CD +
                      "sqlite3 -noheader -list db/alimentos_emy.db < db/procesos/plan_json.sql"}),
    node("a1b2c3d4-0001-4000-8000-000000000007", "Armar hoja de ruta (RF7)", "n8n-nodes-base.code", 2,
         [1200, 100], {"jsCode": CODE_JS},
         notes="BPMN: 'Publicar hoja de ruta y orden de carga'"),
    node("a1b2c3d4-0001-4000-8000-000000000008", "Enviar plan al dueño", "n8n-nodes-base.emailSend", 2.1,
         [1440, 100], {"fromEmail": "sig.alimentosemy@ejemplo.cl",
                       "toEmail": "={{ $('Configuración').first().json.correo_destino }}",
                       "subject": "={{ $json.asunto }}",
                       "emailFormat": "html",
                       "html": "={{ $json.html }}",
                       "options": {}},
         notes="Requiere una credencial SMTP creada en n8n (no se versiona por seguridad)"),
]

CODE_MENSUAL_JS = r"""// BPMN: "Enviar reporte de cumplimiento al dueño" (lane SIG, ciclo mensual)
const data = JSON.parse($input.first().json.stdout);
const fmt = n => n.toLocaleString('es-CL');
let html = `<h2>Cumplimiento de la meta de crecimiento (+${data.meta_pct} % interanual)</h2>`;
html += '<table border="1" cellpadding="4" cellspacing="0"><tr><th>Mes</th><th>Venta año anterior</th><th>Venta actual</th><th>% de la meta</th><th>Estado</th></tr>';
html += data.meses.map(m => `<tr><td>${m.periodo}</td><td align="right">$${fmt(m.venta_anio_anterior)}</td>` +
  `<td align="right">$${fmt(m.venta_actual)}</td><td align="right">${m.cumplimiento_pct} %</td><td>${m.estado}</td></tr>`).join('');
html += '</table>';
const ultimo = data.meses[data.meses.length - 1];
const asunto = `Cumplimiento meta ${ultimo.periodo}: ${ultimo.cumplimiento_pct} % (${ultimo.estado})`;
return [{ json: { asunto, html } }];
"""

CD_M = "cd \"{{ $('Configuración mensual').first().json.repo_path }}\" && "

nodes += [
    node("a1b2c3d4-0001-4000-8000-000000000009", "Día 1 de cada mes 08:00", "n8n-nodes-base.scheduleTrigger", 1.2,
         [0, 420], {"rule": {"interval": [{"field": "months", "monthsInterval": 1, "triggerAtDayOfMonth": 1,
                                           "triggerAtHour": 8, "triggerAtMinute": 0}]}},
         notes="BPMN: evento de inicio temporizador 'Día 1 de cada mes'"),
    node("a1b2c3d4-0001-4000-8000-000000000010", "Configuración mensual", "n8n-nodes-base.set", 3.4,
         [240, 420], {"assignments": {"assignments": [
             {"id": "cfg-m1", "name": "repo_path", "value": "/RUTA/A/ICN292-Proyecto", "type": "string"},
             {"id": "cfg-m2", "name": "correo_destino", "value": "correo-del-dueno@ejemplo.cl", "type": "string"}]},
             "options": {}},
         notes="Mismos valores que el nodo Configuración"),
    node("a1b2c3d4-0001-4000-8000-000000000011", "Calcular cumplimiento meta (RF8)", "n8n-nodes-base.executeCommand", 1,
         [480, 420], {"command": "=" + CD_M +
                      "sqlite3 -noheader -list db/alimentos_emy.db < db/procesos/cumplimiento_json.sql"},
         notes="BPMN: 'Calcular cumplimiento de meta +30 %' (misma lógica que la consulta Q1)"),
    node("a1b2c3d4-0001-4000-8000-000000000012", "Armar reporte de cumplimiento", "n8n-nodes-base.code", 2,
         [720, 420], {"jsCode": CODE_MENSUAL_JS}),
    node("a1b2c3d4-0001-4000-8000-000000000013", "Enviar reporte al dueño", "n8n-nodes-base.emailSend", 2.1,
         [960, 420], {"fromEmail": "sig.alimentosemy@ejemplo.cl",
                      "toEmail": "={{ $('Configuración mensual').first().json.correo_destino }}",
                      "subject": "={{ $json.asunto }}",
                      "emailFormat": "html",
                      "html": "={{ $json.html }}",
                      "options": {}},
         notes="BPMN: 'Enviar reporte de cumplimiento al dueño'"),
]

connections = {
    "Día 1 de cada mes 08:00": {"main": [[{"node": "Configuración mensual", "type": "main", "index": 0}]]},
    "Configuración mensual": {"main": [[{"node": "Calcular cumplimiento meta (RF8)", "type": "main", "index": 0}]]},
    "Calcular cumplimiento meta (RF8)": {"main": [[{"node": "Armar reporte de cumplimiento", "type": "main", "index": 0}]]},
    "Armar reporte de cumplimiento": {"main": [[{"node": "Enviar reporte al dueño", "type": "main", "index": 0}]]},
    "Domingo 19:00": {"main": [[{"node": "Configuración", "type": "main", "index": 0}]]},
    "Ejecutar ahora (demo)": {"main": [[{"node": "Configuración", "type": "main", "index": 0}]]},
    "Configuración": {"main": [[{"node": "Importar ventas Bicom (RF1)", "type": "main", "index": 0}]]},
    "Importar ventas Bicom (RF1)": {"main": [[{"node": "Generar plan y alertas (RF2-RF6, RF9)", "type": "main", "index": 0}]]},
    "Generar plan y alertas (RF2-RF6, RF9)": {"main": [[{"node": "Leer plan en JSON", "type": "main", "index": 0}]]},
    "Leer plan en JSON": {"main": [[{"node": "Armar hoja de ruta (RF7)", "type": "main", "index": 0}]]},
    "Armar hoja de ruta (RF7)": {"main": [[{"node": "Enviar plan al dueño", "type": "main", "index": 0}]]},
}

workflow = {
    "name": "Alimentos Emy · Plan semanal de rutas y carga (ICN-292 E2)",
    "nodes": nodes,
    "connections": connections,
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "America/Santiago"},
    "pinData": {},
    "meta": {"templateCredsSetupCompleted": False},
    "tags": [],
}

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(workflow, ensure_ascii=False, indent=2), encoding="utf-8")
print("Escrito", OUT)
