"""
Genera db/seed.sql con datos sintéticos para Alimentos Emy (ICN-292, E2).

Los datos son sintéticos y anonimizados (Ley 21.719). Se calibraron con las magnitudes
que el dueño declaró en el levantamiento de la E1:
  * 45 clientes activos, canal tradicional, zonas Rancagua / Machalí / Doñihue-Olivar
  * 3 rutas semanales fijas + ruta de fin de semana, un solo vehículo
  * temporada baja marzo–agosto
  * meta de crecimiento interanual de 30 %: cumplida ene–may 2026, no cumplida jun–ago 2026
Ninguna cifra de este archivo corresponde a transacciones reales de la PYME.

Uso:  python3 scripts/generar_seed.py            -> escribe db/seed.sql
Usa una semilla fija (292), así que el seed.sql sale igual en cualquier computador.
Solo necesita Python 3, sin librerías extra.
"""
import random
from datetime import date, timedelta
from pathlib import Path

random.seed(292)
OUT = Path(__file__).resolve().parent.parent / "db" / "seed.sql"

FECHA_INICIO = date(2025, 1, 1)
FECHA_CORTE = date(2026, 11, 14)  # último sábado con datos (corte de la exportación)

# ------------------------------------------------------------------ maestros
PARAMETROS = [
    ("META_CRECIMIENTO_INTERANUAL", 0.30, "Meta de crecimiento de venta vs. mismo mes del año anterior"),
    ("SEMANAS_HISTORIA_PLAN", 12, "Semanas de historia usadas para estimar la demanda por visita"),
    ("FACTOR_SEGURIDAD_CARGA", 1.10, "Holgura sobre la demanda esperada para evitar quiebres en el camión"),
    ("SEMANAS_VENTANA_RECIENTE", 8, "Ventana reciente para detectar caída de frecuencia de compra"),
    ("SEMANAS_VENTANA_HISTORICA", 26, "Ventana histórica (previa a la reciente) para comparar frecuencia"),
    ("UMBRAL_CAIDA_FRECUENCIA", 0.60, "Alerta si compras/semana reciente < umbral x compras/semana histórica"),
]

ZONAS = [
    ("Z01", "Rancagua Centro-Norte", "Rancagua"),
    ("Z02", "Rancagua Sur", "Rancagua"),
    ("Z03", "Machalí", "Machalí"),
    ("Z04", "Doñihue-Olivar", "Doñihue"),
]

FAMILIAS = [
    ("QLA", "Quesos laminados", 1),
    ("QTR", "Quesos en trozo", 1),
    ("LEC", "Leches", 0),
    ("MAN", "Mantequillas", 1),
    ("YOG", "Yoghurt y postres", 1),
    ("HUE", "Huevos", 0),
    ("ABA", "Abarrotes", 0),
]

# sku, nombre, marca, familia, peso_kg, precio_lista (CLP neto, nov-2026), unidades base por visita semanal
PRODUCTOS = [
    ("QL-001", "Queso gauda laminado 250 g", "Colun", "QLA", 0.25, 2300, 6),
    ("QL-002", "Queso gauda laminado 500 g", "Colun", "QLA", 0.50, 4200, 5),
    ("QL-003", "Queso mantecoso laminado 500 g", "Quillayes", "QLA", 0.50, 4000, 4),
    ("QL-004", "Queso laminado familiar 1 kg", "Surlat", "QLA", 1.00, 7800, 2),
    ("QT-001", "Queso mantecoso trozo 1 kg", "Colun", "QTR", 1.00, 7200, 2),
    ("QT-002", "Queso chanco trozo 1 kg", "Quillayes", "QTR", 1.00, 7000, 2),
    ("LE-001", "Leche entera 1 L (pack 12)", "Colun", "LEC", 12.6, 11400, 3),
    ("LE-002", "Leche semidescremada 1 L (pack 12)", "Colun", "LEC", 12.6, 11400, 2),
    ("LE-003", "Leche sin lactosa 1 L (pack 12)", "Surlat", "LEC", 12.6, 13800, 1),
    ("MA-001", "Mantequilla sin sal 250 g", "Colun", "MAN", 0.25, 2400, 6),
    ("MA-002", "Mantequilla con sal 250 g", "Quillayes", "MAN", 0.25, 2300, 4),
    ("YO-001", "Yoghurt batido 125 g (pack 12)", "Colun", "YOG", 1.60, 3900, 3),
    ("YO-002", "Yoghurt familiar 1 kg", "Surlat", "YOG", 1.05, 2100, 3),
    ("YO-003", "Manjar 1 kg", "Colun", "YOG", 1.05, 3800, 2),
    ("YO-004", "Crema de leche 200 ml", "Colun", "YOG", 0.21, 900, 6),
    ("HU-001", "Huevos bandeja 30 un", "Granja local", "HUE", 1.85, 6900, 3),
    ("HU-002", "Huevos caja 12 un", "Granja local", "HUE", 0.75, 3000, 3),
    ("AB-001", "Arroz grado 2 1 kg", "Genérico", "ABA", 1.00, 1300, 5),
    ("AB-002", "Aceite vegetal 1 L", "Genérico", "ABA", 0.92, 2200, 4),
    ("AB-003", "Azúcar granulada 1 kg", "Genérico", "ABA", 1.00, 1100, 5),
    ("AB-004", "Fideos spaghetti 400 g", "Genérico", "ABA", 0.40, 850, 6),
]

VEHICULOS = [("V01", "Furgón refrigerado compacto (único vehículo de la PYME)", 480.0)]

RUTAS = [  # id, nombre, dia_semana (1=lunes), zona
    ("R-LUN", "Ruta lunes Rancagua Centro-Norte", 1, "Z01"),
    ("R-MIE", "Ruta miércoles Machalí", 3, "Z03"),
    ("R-VIE", "Ruta viernes Doñihue-Olivar", 5, "Z04"),
    ("R-SAB", "Ruta sábado Rancagua Sur", 6, "Z02"),
]
RUTA_DE_ZONA = {r[3]: r[0] for r in RUTAS}
DIA_DE_RUTA = {r[0]: r[2] for r in RUTAS}

TIPOS = ["MINIMARKET", "ALMACEN", "ALMACEN", "MINIMARKET", "BOTILLERIA", "PANADERIA"]
CLIENTES_POR_ZONA = {"Z01": 14, "Z02": 11, "Z03": 11, "Z04": 9}
FRECUENCIAS = ["SEMANAL"] * 20 + ["QUINCENAL"] * 15 + ["MENSUAL"] * 10
random.shuffle(FRECUENCIAS)

# Altas de clientes posteriores al inicio del período (crecimiento de cartera)
ALTAS_NUEVAS = [date(2025, 3, 10), date(2025, 5, 5), date(2025, 7, 14), date(2025, 9, 1),
                date(2025, 11, 3), date(2026, 2, 2), date(2026, 4, 6), date(2026, 7, 6),
                date(2026, 9, 7)]
# Clientes que reducen su frecuencia de compra desde mediados de septiembre 2026 (para RF9)
CLIENTES_EN_CAIDA = {"CLI-007", "CLI-019", "CLI-033"}
INICIO_CAIDA = date(2026, 9, 14)

ESTACIONALIDAD = {1: 1.05, 2: 1.00, 3: 0.82, 4: 0.80, 5: 0.78, 6: 0.74,
                  7: 0.74, 8: 0.78, 9: 0.95, 10: 1.00, 11: 1.05, 12: 1.15}
# Factor de volumen por visita 2026 vs 2025 (ventas por cliente)
CRECIMIENTO_2026 = {1: 1.11, 2: 1.11, 3: 1.21, 4: 1.13, 5: 1.09, 6: 0.98,
                    7: 0.84, 8: 1.05, 9: 1.12, 10: 1.18, 11: 1.12}
INFLACION_2025 = 0.96  # precios 2025 = 96 % del precio de lista 2026
MULT_FRECUENCIA = {"SEMANAL": 1.0, "QUINCENAL": 1.8, "MENSUAL": 3.2}


def sql_str(v):
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def insert_rows(table, cols, rows, chunk=400):
    out = []
    for i in range(0, len(rows), chunk):
        part = rows[i:i + chunk]
        vals = ",\n".join("(" + ", ".join(sql_str(v) for v in r) + ")" for r in part)
        out.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n{vals};")
    return "\n".join(out)


def main():
    # ---------------- clientes
    clientes = []  # (id, nombre, tipo, zona, frecuencia, alta)
    perfil = {}    # id -> (escala, canasta de skus)
    n = 0
    altas = ALTAS_NUEVAS[:]
    idx_nuevos = set(random.sample(range(45), len(altas)))
    for zona, cant in CLIENTES_POR_ZONA.items():
        for _ in range(cant):
            n += 1
            cid = f"CLI-{n:03d}"
            if cid in CLIENTES_EN_CAIDA:
                idx_nuevos.discard(n - 1)
            alta = altas.pop(0) if (n - 1) in idx_nuevos and altas else date(2022 + n % 3, 1 + n % 12, 1 + n % 27)
            tipo = TIPOS[n % len(TIPOS)]
            clientes.append((cid, f"Cliente {zona}-{n:03d}", tipo, zona, FRECUENCIAS[n - 1], alta.isoformat()))
            escala = random.choice([0.6, 0.8, 1.0, 1.0, 1.3, 1.6])
            canasta = random.sample([p[0] for p in PRODUCTOS], random.randint(7, 12))
            if tipo == "PANADERIA":
                canasta = sorted(set(canasta) | {"MA-001", "HU-001", "QL-002"})
            perfil[cid] = (escala, canasta)

    # ruta_cliente con orden de visita
    ruta_cliente = []
    for zona in CLIENTES_POR_ZONA:
        miembros = [c for c in clientes if c[3] == zona]
        random.shuffle(miembros)
        for orden, c in enumerate(miembros, start=1):
            ruta_cliente.append((RUTA_DE_ZONA[zona], c[0], orden))

    precio = {p[0]: p[5] for p in PRODUCTOS}
    base = {p[0]: p[6] for p in PRODUCTOS}

    # ---------------- visitas / ventas / detalle
    visitas, ventas, detalles = [], [], []
    id_visita = id_venta = 0
    d = FECHA_INICIO
    semana_idx = {}
    while d <= FECHA_CORTE:
        dia = d.isoweekday()
        for (rid, _nom, dsem, zona) in RUTAS:
            if dsem != dia:
                continue
            nro_semana = (d - date(2024, 12, 30)).days // 7
            for (r, cid, _o) in [rc for rc in ruta_cliente if rc[0] == rid]:
                c = next(x for x in clientes if x[0] == cid)
                if d < date.fromisoformat(c[5]):
                    continue
                freq = c[4]
                desfase = int(cid[-3:])
                if freq == "QUINCENAL" and (nro_semana + desfase) % 2:
                    continue
                if freq == "MENSUAL" and (nro_semana + desfase) % 4:
                    continue
                # resultado de la visita
                p_venta = 0.86
                if cid in CLIENTES_EN_CAIDA and d >= INICIO_CAIDA:
                    p_venta = 0.15
                elif d.month in (3, 6, 7):
                    p_venta = 0.82
                u = random.random()
                if u < p_venta:
                    res = "VENTA"
                elif u < p_venta + (1 - p_venta) * 0.45:
                    res = "SIN_REPOSICION"
                elif u < p_venta + (1 - p_venta) * 0.80:
                    res = "AUSENTE"
                else:
                    res = "SIN_SALDO"
                id_visita += 1
                visitas.append((id_visita, rid, cid, d.isoformat(), res))
                if res != "VENTA":
                    continue
                id_venta += 1
                tipo_doc = "FACTURA" if random.random() < 0.7 else "BOLETA"
                medio = random.choices(["EFECTIVO", "TRANSFERENCIA", "TARJETA"], [0.45, 0.40, 0.15])[0]
                ventas.append((id_venta, id_visita, f"B-{id_venta:06d}", tipo_doc, medio))
                escala, canasta = perfil[cid]
                factor = ESTACIONALIDAD[d.month] * escala * MULT_FRECUENCIA[freq]
                if d.year == 2026:
                    factor *= CRECIMIENTO_2026[d.month]
                lineas = [s for s in canasta if random.random() < 0.72] or [canasta[0]]
                for sku in lineas:
                    q = base[sku] * factor * random.uniform(0.6, 1.4)
                    sol = max(1, int(round(q)))
                    p_quiebre = 0.05 + (0.06 if d.month in (6, 7, 8) else 0.0)
                    if random.random() < p_quiebre:
                        des = int(sol * random.uniform(0.0, 0.7))
                    else:
                        des = sol
                    pu = precio[sku] if d.year == 2026 else int(round(precio[sku] * INFLACION_2025 / 10) * 10)
                    detalles.append((id_venta, sku, sol, des, pu))
        d += timedelta(days=1)

    # ---------------- escribir seed.sql
    parts = [
        "-- seed.sql - datos de prueba de Alimentos Emy (sintéticos y anonimizados)",
        "-- Lo genera scripts/generar_seed.py con semilla 292, así que no conviene editarlo a mano.",
        f"-- Período {FECHA_INICIO} a {FECHA_CORTE}: {len(clientes)} clientes, "
        f"{len(visitas)} visitas, {len(ventas)} ventas, {len(detalles)} líneas",
        "-- Uso: sqlite3 db/alimentos_emy.db < db/seed.sql  (después de schema.sql)",
        "PRAGMA foreign_keys = ON;",
        "BEGIN TRANSACTION;",
        insert_rows("parametro", ["clave", "valor", "descripcion"], PARAMETROS),
        insert_rows("zona", ["id_zona", "nombre", "comuna"], ZONAS),
        insert_rows("cliente", ["id_cliente", "nombre_fantasia", "tipo_negocio", "id_zona",
                                "frecuencia_visita", "fecha_alta"], clientes),
        insert_rows("familia_producto", ["id_familia", "nombre", "requiere_frio"], FAMILIAS),
        insert_rows("producto", ["sku", "nombre", "marca", "id_familia", "peso_kg", "precio_lista"],
                    [p[:6] for p in PRODUCTOS]),
        insert_rows("vehiculo", ["id_vehiculo", "descripcion", "capacidad_kg"], VEHICULOS),
        insert_rows("ruta", ["id_ruta", "nombre", "dia_semana", "id_zona", "id_vehiculo"],
                    [(r[0], r[1], r[2], r[3], "V01") for r in RUTAS]),
        insert_rows("ruta_cliente", ["id_ruta", "id_cliente", "orden_visita"], ruta_cliente),
        insert_rows("visita", ["id_visita", "id_ruta", "id_cliente", "fecha", "resultado"], visitas),
        insert_rows("venta", ["id_venta", "id_visita", "folio_bicom", "tipo_documento", "medio_pago"], ventas),
        insert_rows("detalle_venta", ["id_venta", "sku", "cantidad_solicitada", "cantidad_despachada",
                                      "precio_unitario"], detalles),
        "COMMIT;",
        "",
    ]
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"seed.sql escrito: {len(clientes)} clientes, {len(visitas)} visitas, "
          f"{len(ventas)} ventas, {len(detalles)} líneas -> {OUT}")


if __name__ == "__main__":
    main()
