"""
Genera bpmn/to-be-final-e2.bpmn (BPMN 2.0 XML con diagrama) del proceso to-be de Alimentos Emy.
El .bpmn se abre y edita en https://demo.bpmn.io o Camunda Modeler; la imagen PNG del
informe se renderiza desde este mismo archivo.  Uso: python3 scripts/construir_bpmn.py
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent.parent / "bpmn" / "to-be-final-e2.bpmn"

POOL_X, POOL_Y, POOL_W = 120, 40, 2860
LANE_DUENO_H, LANE_SIG_H = 360, 440
TW, TH = 130, 80  # tarea
GW = 50           # gateway
EV = 36           # evento

# id: (tipo, nombre, cx, cy, lane, extra)
D, S = "lane_dueno", "lane_sig"
E = {
    # ---------------- lane SIG: ciclo semanal (automatizado con n8n)
    "ev_domingo": ("startEvent:timer", "Domingo 19:00", 230, 520, S, ""),
    "t_importar": ("serviceTask", "Importar ventas exportadas desde Bicom [n8n 1]", 340, 520, S, "RF1"),
    "t_demanda": ("serviceTask", "Calcular demanda esperada por cliente y SKU [n8n 2]", 510, 520, S, "RF2"),
    "t_seleccion": ("serviceTask", "Seleccionar clientes a visitar (reagenda visitas fallidas) [n8n 2]", 680, 520, S, "RF3, RF4"),
    "gw_split": ("parallelGateway", "", 815, 520, S, ""),
    "t_plan": ("serviceTask", "Generar plan de carga con capacidad del furgón [n8n 2]", 940, 460, S, "RF5, RF6"),
    "t_alertas": ("serviceTask", "Detectar clientes con caída de frecuencia [n8n 2]", 940, 590, S, "RF9"),
    "gw_join": ("parallelGateway", "", 1065, 520, S, ""),
    "t_publicar": ("sendTask", "Publicar hoja de ruta y orden de carga por correo [n8n 3-5]", 1190, 520, S, "RF7"),
    # ---------------- lane SIG: ciclo mensual
    "ev_mes": ("startEvent:timer", "Día 1 de cada mes", 230, 770, S, ""),
    "t_meta": ("serviceTask", "Calcular cumplimiento de meta +30 % [n8n mensual]", 340, 770, S, "RF8"),
    "t_reporte": ("sendTask", "Enviar reporte de cumplimiento al dueño [n8n mensual]", 510, 770, S, "RF8"),
    "ev_fin_mes": ("endEvent", "Reporte enviado", 630, 770, S, ""),
    # ---------------- lane Dueño / operador
    "t_revisar": ("userTask", "Revisar plan sugerido", 1350, 200, D, ""),
    "gw_ajuste": ("exclusiveGateway", "¿Requiere ajustes?", 1480, 200, D, ""),
    "t_ajustar": ("userTask", "Ajustar y aprobar plan en el SIG", 1600, 310, D, ""),
    "gw_ajuste_m": ("exclusiveGateway", "", 1720, 200, D, ""),
    "ev_dia_ruta": ("intermediateCatchEvent:timer", "Día de ruta (lun-mié-vie-sáb)", 1810, 200, D, ""),
    "t_cargar": ("manualTask", "Cargar furgón según orden de carga", 1920, 200, D, ""),
    "t_visitar": ("userTask", "Visitar siguiente cliente de la hoja de ruta", 2080, 200, D, "RF10"),
    "gw_disp": ("exclusiveGateway", "¿Disponible, con saldo y requiere reposición?", 2210, 200, D, ""),
    "t_vender": ("userTask", "Atender, emitir documento en Bicom y despachar", 2340, 110, D, ""),
    "t_incidencia": ("userTask", "Registrar incidencia de visita (el SIG la reagenda)", 2340, 300, D, ""),
    "gw_disp_m": ("exclusiveGateway", "", 2470, 200, D, ""),
    "gw_quedan": ("exclusiveGateway", "¿Quedan clientes en la hoja de ruta?", 2560, 200, D, ""),
    "t_cuadrar": ("userTask", "Cuadrar carga devuelta vs. vendido", 2690, 200, D, ""),
    "t_caja": ("userTask", "Cierre de caja diario", 2690, 330, D, ""),
    "ev_fin_dia": ("endEvent", "Jornada cerrada", 2830, 330, D, ""),
}

STORES = {
    "ds_bicom": ("ERP Bicom (exportación CSV)", 340, 640),
    "ds_sig": ("BD SIG (SQLite)", 680, 650),
    "ds_bicom_app": ("App Bicom (terreno)", 2700, 75),
}

FLOWS = [
    ("f1", "ev_domingo", "t_importar", ""),
    ("f2", "t_importar", "t_demanda", ""),
    ("f3", "t_demanda", "t_seleccion", ""),
    ("f4", "t_seleccion", "gw_split", ""),
    ("f5", "gw_split", "t_plan", ""),
    ("f6", "gw_split", "t_alertas", ""),
    ("f7", "t_plan", "gw_join", ""),
    ("f8", "t_alertas", "gw_join", ""),
    ("f9", "gw_join", "t_publicar", ""),
    ("f10", "t_publicar", "t_revisar", ""),
    ("f11", "t_revisar", "gw_ajuste", ""),
    ("f12", "gw_ajuste", "t_ajustar", "sí"),
    ("f13", "gw_ajuste", "gw_ajuste_m", "no"),
    ("f14", "t_ajustar", "gw_ajuste_m", ""),
    ("f15", "gw_ajuste_m", "ev_dia_ruta", ""),
    ("f16", "ev_dia_ruta", "t_cargar", ""),
    ("f17", "t_cargar", "t_visitar", ""),
    ("f18", "t_visitar", "gw_disp", ""),
    ("f19", "gw_disp", "t_vender", "sí"),
    ("f20", "gw_disp", "t_incidencia", "no"),
    ("f21", "t_vender", "gw_disp_m", ""),
    ("f22", "t_incidencia", "gw_disp_m", ""),
    ("f23", "gw_disp_m", "gw_quedan", ""),
    ("f24", "gw_quedan", "t_visitar", "sí"),
    ("f25", "gw_quedan", "t_cuadrar", "no"),
    ("f26", "t_cuadrar", "t_caja", ""),
    ("f27", "t_caja", "ev_fin_dia", ""),
    ("f28", "ev_mes", "t_meta", ""),
    ("f29", "t_meta", "t_reporte", ""),
    ("f30", "t_reporte", "ev_fin_mes", ""),
]

# (tarea, store, dirección)  in = la tarea lee del store, out = la tarea escribe
DATA = [
    ("t_importar", "ds_bicom", "in"), ("t_importar", "ds_sig", "out"),
    ("t_seleccion", "ds_sig", "in"), ("t_plan", "ds_sig", "out"), ("t_alertas", "ds_sig", "out"),
    ("t_meta", "ds_sig", "in"),
    ("t_vender", "ds_bicom_app", "out"),
]

# waypoints especiales (el resto se calcula con codos ortogonales)
SPECIAL = {
    "f10": [(1255, 520), (1350, 520), (1350, 240)],
    "f12": [(1480, 225), (1480, 310), (1535, 310)],
    "f14": [(1665, 310), (1720, 310), (1720, 225)],
    "f19": [(2210, 175), (2210, 110), (2275, 110)],
    "f20": [(2210, 225), (2210, 300), (2275, 300)],
    "f21": [(2405, 110), (2470, 110), (2470, 175)],
    "f22": [(2405, 300), (2470, 300), (2470, 225)],
    "f24": [(2560, 225), (2560, 380), (2080, 380), (2080, 240)],
    "f5": [(815, 495), (815, 460), (875, 460)],
    "f6": [(815, 545), (815, 590), (875, 590)],
    "f7": [(1005, 460), (1065, 460), (1065, 495)],
    "f8": [(1005, 590), (1065, 590), (1065, 545)],
}


def size(kind):
    if "Task" in kind:
        return TW, TH
    if "Gateway" in kind:
        return GW, GW
    return EV, EV


def bounds(eid):
    kind, _n, cx, cy, *_ = E[eid]
    w, h = size(kind)
    return cx - w / 2, cy - h / 2, w, h


def right(eid):
    x, y, w, h = bounds(eid)
    return x + w, y + h / 2


def left(eid):
    x, y, w, h = bounds(eid)
    return x, y + h / 2


def waypoints(fid, s, t):
    if fid in SPECIAL:
        return SPECIAL[fid]
    sx, sy = right(s)
    tx, ty = left(t)
    if abs(sy - ty) < 1:
        return [(sx, sy), (tx, ty)]
    if fid == "f25":  # gw_quedan -> cuadrar (misma altura)
        return [(sx, sy), (tx, ty)]
    if fid == "f26":
        x, y, w, h = bounds(s)
        x2, y2, w2, h2 = bounds(t)
        return [(x + w / 2, y + h), (x2 + w2 / 2, y2)]
    mx = (sx + tx) / 2
    return [(sx, sy), (mx, sy), (mx, ty), (tx, ty)]


def element_xml(eid):
    kind, name, *_rest = E[eid]
    extra = E[eid][5]
    nm = escape(name, {'"': "&quot;"})
    inc = [f for f in FLOWS if f[2] == eid]
    out = [f for f in FLOWS if f[1] == eid]
    body = "".join(f"<bpmn:incoming>{f[0]}</bpmn:incoming>" for f in inc)
    body += "".join(f"<bpmn:outgoing>{f[0]}</bpmn:outgoing>" for f in out)
    doc = f"<bpmn:documentation>Requerimientos: {extra}</bpmn:documentation>" if extra else ""
    # asociaciones de datos
    das = ""
    for i, (task, store, d) in enumerate(DATA):
        if task != eid:
            continue
        if d == "in":
            das += (f'<bpmn:property id="prop_{eid}_{i}" name="__targetRef_placeholder" />'
                    f'<bpmn:dataInputAssociation id="da_{eid}_{i}"><bpmn:sourceRef>{store}</bpmn:sourceRef>'
                    f'<bpmn:targetRef>prop_{eid}_{i}</bpmn:targetRef></bpmn:dataInputAssociation>')
        else:
            das += (f'<bpmn:dataOutputAssociation id="da_{eid}_{i}"><bpmn:targetRef>{store}</bpmn:targetRef>'
                    f'</bpmn:dataOutputAssociation>')
    if ":" in kind:
        tag, ev = kind.split(":")
        return (f'<bpmn:{tag} id="{eid}" name="{nm}">{doc}{body}'
                f'<bpmn:timerEventDefinition id="td_{eid}" /></bpmn:{tag}>')
    return f'<bpmn:{kind} id="{eid}" name="{nm}">{doc}{body}{das}</bpmn:{kind}>'


def build():
    lanes_xml = ""
    for lane_id, lane_name in ((D, "Dueño / operador de ruta"), (S, "SIG (SQLite + n8n)")):
        refs = "".join(f"<bpmn:flowNodeRef>{e}</bpmn:flowNodeRef>" for e in E if E[e][4] == lane_id)
        lanes_xml += f'<bpmn:lane id="{lane_id}" name="{escape(lane_name)}">{refs}</bpmn:lane>'
    proc = [f'<bpmn:laneSet id="laneset">{lanes_xml}</bpmn:laneSet>']
    proc += [element_xml(e) for e in E]
    for sid, (name, _x, _y) in STORES.items():
        proc.append(f'<bpmn:dataStoreReference id="{sid}" name="{escape(name)}" />')
    for fid, s, t, name in FLOWS:
        nm = f' name="{escape(name)}"' if name else ""
        proc.append(f'<bpmn:sequenceFlow id="{fid}"{nm} sourceRef="{s}" targetRef="{t}" />')
    proc.append('<bpmn:textAnnotation id="ann_n8n"><bpmn:text>Ciclos semanal y mensual automatizados con el flujo n8n '
                '"Plan semanal de rutas y carga" (automatizacion/n8n_plan_semanal_emy.json). '
                '[n8n k] = nodo que ejecuta la tarea.</bpmn:text></bpmn:textAnnotation>')
    proc.append('<bpmn:association id="as_n8n" sourceRef="ann_n8n" targetRef="t_importar" />')

    # ---------------- DI
    di = []
    pool_h = LANE_DUENO_H + LANE_SIG_H
    di.append(f'<bpmndi:BPMNShape id="pool_di" bpmnElement="participant" isHorizontal="true">'
              f'<dc:Bounds x="{POOL_X}" y="{POOL_Y}" width="{POOL_W}" height="{pool_h}" /></bpmndi:BPMNShape>')
    di.append(f'<bpmndi:BPMNShape id="{D}_di" bpmnElement="{D}" isHorizontal="true">'
              f'<dc:Bounds x="{POOL_X + 30}" y="{POOL_Y}" width="{POOL_W - 30}" height="{LANE_DUENO_H}" /></bpmndi:BPMNShape>')
    di.append(f'<bpmndi:BPMNShape id="{S}_di" bpmnElement="{S}" isHorizontal="true">'
              f'<dc:Bounds x="{POOL_X + 30}" y="{POOL_Y + LANE_DUENO_H}" width="{POOL_W - 30}" height="{LANE_SIG_H}" /></bpmndi:BPMNShape>')
    for e in E:
        x, y, w, h = bounds(e)
        kind = E[e][0]
        label = ""
        if "Task" not in kind and E[e][1]:
            lw = 110
            ly = y - 38 if "Gateway" in kind else y + h + 5
            if e in ("gw_disp", "gw_quedan", "gw_ajuste"):
                ly = y - 48
            label = (f'<bpmndi:BPMNLabel><dc:Bounds x="{x + w / 2 - lw / 2}" y="{ly}" width="{lw}" height="40" />'
                     f'</bpmndi:BPMNLabel>')
        marker = ' isMarkerVisible="true"' if kind == "exclusiveGateway" else ""
        di.append(f'<bpmndi:BPMNShape id="{e}_di" bpmnElement="{e}"{marker}>'
                  f'<dc:Bounds x="{x}" y="{y}" width="{w}" height="{h}" />{label}</bpmndi:BPMNShape>')
    for sid, (_n, cx, cy) in STORES.items():
        di.append(f'<bpmndi:BPMNShape id="{sid}_di" bpmnElement="{sid}">'
                  f'<dc:Bounds x="{cx - 25}" y="{cy - 25}" width="50" height="50" /></bpmndi:BPMNShape>')
    di.append('<bpmndi:BPMNShape id="ann_n8n_di" bpmnElement="ann_n8n">'
              '<dc:Bounds x="200" y="420" width="420" height="44" /></bpmndi:BPMNShape>')
    di.append('<bpmndi:BPMNEdge id="as_n8n_di" bpmnElement="as_n8n">'
              '<di:waypoint x="340" y="464" /><di:waypoint x="340" y="480" /></bpmndi:BPMNEdge>')
    for fid, s, t, name in FLOWS:
        pts = "".join(f'<di:waypoint x="{px}" y="{py}" />' for px, py in waypoints(fid, s, t))
        lab = ""
        if name:
            wp = waypoints(fid, s, t)
            lx, ly = wp[1] if len(wp) > 2 else wp[0]
            lab = f'<bpmndi:BPMNLabel><dc:Bounds x="{lx + 4}" y="{ly - 16}" width="22" height="14" /></bpmndi:BPMNLabel>'
        di.append(f'<bpmndi:BPMNEdge id="{fid}_di" bpmnElement="{fid}">{pts}{lab}</bpmndi:BPMNEdge>')
    for i, (task, store, d) in enumerate(DATA):
        _n, scx, scy = STORES[store]
        x, y, w, h = bounds(task)
        tcx, tcy = x + w / 2, y + h / 2
        ty = y + h if scy > tcy else y
        sy = scy - 25 if scy > tcy else scy + 25
        if d == "in":
            pts = [(scx, sy), (tcx, ty)]
        else:
            pts = [(tcx, ty), (scx, sy)]
        wp = "".join(f'<di:waypoint x="{px}" y="{py}" />' for px, py in pts)
        di.append(f'<bpmndi:BPMNEdge id="da_{task}_{i}_di" bpmnElement="da_{task}_{i}">{wp}</bpmndi:BPMNEdge>')

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
  xmlns:di="http://www.omg.org/spec/DD/20100524/DI"
  id="defs_emy_tobe_e2" targetNamespace="http://usm.cl/icn292/alimentos-emy"
  exporter="scripts/construir_bpmn.py" exporterVersion="1.0">
  <bpmn:collaboration id="collab">
    <bpmn:participant id="participant" name="Alimentos Emy · Proceso to-be final (E2)" processRef="proc_tobe" />
  </bpmn:collaboration>
  <bpmn:process id="proc_tobe" name="Planificación de rutas y carga, autoventa y control" isExecutable="false">
    {"".join(proc)}
  </bpmn:process>
  <bpmndi:BPMNDiagram id="diagram">
    <bpmndi:BPMNPlane id="plane" bpmnElement="collab">
      {"".join(di)}
    </bpmndi:BPMNPlane>
  </bpmndi:BPMNDiagram>
</bpmn:definitions>
'''
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(xml, encoding="utf-8")
    print("Escrito", OUT)


if __name__ == "__main__":
    build()
