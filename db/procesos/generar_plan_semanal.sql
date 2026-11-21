-- Plan de la próxima semana: qué clientes visitar y cuánto cargar de cada producto.
-- Son las tareas del lane SIG en el BPMN to-be (calcular demanda, elegir clientes,
-- armar la carga sin pasarse de la capacidad y detectar clientes que compran menos).
-- n8n lo corre todos los domingos a las 19:00 (docs/05-automatizacion-n8n.md),
-- pero también se puede correr a mano:
--     sqlite3 db/alimentos_emy.db < db/procesos/generar_plan_semanal.sql
-- Si se corre de nuevo, borra los planes SUGERIDO y los vuelve a calcular (no duplica).
-- Necesita SQLite 3.35 o más nuevo porque usa funciones de ventana (OVER).

PRAGMA foreign_keys = ON;
.bail on

-- 0. Contexto
-- La fecha de corte es la última visita registrada y no la fecha del computador,
-- así el resultado da igual en cualquier PC.
DROP TABLE IF EXISTS temp.ctx;
CREATE TEMP TABLE ctx AS
SELECT MAX(fecha) AS fecha_corte,
       (SELECT valor FROM parametro WHERE clave = 'SEMANAS_HISTORIA_PLAN')   AS sem_hist,
       (SELECT valor FROM parametro WHERE clave = 'FACTOR_SEGURIDAD_CARGA')  AS fs
FROM visita;

-- 1. Próxima fecha de cada ruta
-- strftime('%w') entrega 0 = domingo ... 6 = sábado; lo pasamos a 1 = lunes ... 7 = domingo
-- para compararlo con ruta.dia_semana
DROP TABLE IF EXISTS temp.prox_ruta;
CREATE TEMP TABLE prox_ruta AS
SELECT r.id_ruta,
       r.id_vehiculo,
       date(c.fecha_corte,
            '+' || (((r.dia_semana - ((CAST(strftime('%w', c.fecha_corte) AS INTEGER) + 6) % 7 + 1)) + 7) % 7
                    + CASE WHEN r.dia_semana = ((CAST(strftime('%w', c.fecha_corte) AS INTEGER) + 6) % 7 + 1)
                           THEN 7 ELSE 0 END) || ' days') AS fecha_ruta
FROM ruta r, ctx c;

-- 2. Clientes programados (RF4)
-- Los SEMANAL entran siempre. Los QUINCENAL si pasaron 11 días o más desde su última
-- compra y los MENSUAL si pasaron 25 o más.
-- Contamos desde la última compra y no desde la última visita: si la visita falló
-- (no estaba, no tenía plata, no necesitaba) el cliente vuelve a salir la semana siguiente.
DROP TABLE IF EXISTS temp.cli_programados;
CREATE TEMP TABLE cli_programados AS
SELECT pr.id_ruta, pr.fecha_ruta, rc.id_cliente, rc.orden_visita
FROM prox_ruta pr
JOIN ruta_cliente rc ON rc.id_ruta = pr.id_ruta
JOIN cliente c       ON c.id_cliente = rc.id_cliente AND c.activo = 1
LEFT JOIN (SELECT id_cliente, MAX(fecha) AS ultima FROM visita
           WHERE resultado = 'VENTA' GROUP BY id_cliente) u
       ON u.id_cliente = c.id_cliente
WHERE c.frecuencia_visita = 'SEMANAL'
   OR u.ultima IS NULL
   OR julianday(pr.fecha_ruta) - julianday(u.ultima) >=
      CASE c.frecuencia_visita WHEN 'QUINCENAL' THEN 11 ELSE 25 END;

-- 3. Demanda esperada por visita (RF2)
-- Demanda por visita = unidades pedidas en las últimas semanas / visitas en esas semanas
-- (las visitas sin venta también cuentan, si no la demanda queda inflada)
DROP TABLE IF EXISTS temp.demanda_cli;
CREATE TEMP TABLE demanda_cli AS
WITH ventana AS (
    SELECT date(fecha_corte, '-' || CAST(sem_hist * 7 AS INTEGER) || ' days') AS desde, fecha_corte
    FROM ctx),
vis AS (
    SELECT vi.id_cliente, COUNT(*) AS n_visitas
    FROM visita vi, ventana w
    WHERE vi.fecha > w.desde AND vi.fecha <= w.fecha_corte
    GROUP BY vi.id_cliente),
sol AS (
    SELECT vi.id_cliente, d.sku, SUM(d.cantidad_solicitada) AS unidades
    FROM detalle_venta d
    JOIN venta  v  ON v.id_venta   = d.id_venta
    JOIN visita vi ON vi.id_visita = v.id_visita, ventana w
    WHERE vi.fecha > w.desde AND vi.fecha <= w.fecha_corte
    GROUP BY vi.id_cliente, d.sku)
SELECT s.id_cliente, s.sku, 1.0 * s.unidades / v.n_visitas AS q_esperada
FROM sol s JOIN vis v ON v.id_cliente = s.id_cliente;

-- Total por ruta y SKU
DROP TABLE IF EXISTS temp.dem_ruta;
CREATE TEMP TABLE dem_ruta AS
SELECT cp.id_ruta, cp.fecha_ruta, dc.sku, SUM(dc.q_esperada) AS q_base
FROM cli_programados cp
JOIN demanda_cli dc ON dc.id_cliente = cp.id_cliente
GROUP BY cp.id_ruta, cp.fecha_ruta, dc.sku;

-- 4. Plan de carga con capacidad (RF5, RF6)
-- Etapa 1: la demanda redondeada hacia arriba. Si no cabe en el furgón, se baja
-- todo en la misma proporción.
DROP TABLE IF EXISTS temp.etapa1;
CREATE TEMP TABLE etapa1 AS
WITH b AS (
    SELECT d.id_ruta, d.fecha_ruta, d.sku, p.peso_kg, p.precio_lista,
           CAST(d.q_base AS INTEGER) + (d.q_base > CAST(d.q_base AS INTEGER))                     AS u_base,
           CAST(d.q_base * c.fs AS INTEGER) + (d.q_base * c.fs > CAST(d.q_base * c.fs AS INTEGER)) AS u_seg
    FROM dem_ruta d JOIN producto p ON p.sku = d.sku, ctx c),
k AS (
    SELECT b.id_ruta, SUM(b.u_base * b.peso_kg) AS kg_base, v.capacidad_kg AS cap
    FROM b JOIN ruta r ON r.id_ruta = b.id_ruta JOIN vehiculo v ON v.id_vehiculo = r.id_vehiculo
    GROUP BY b.id_ruta, v.capacidad_kg)
SELECT b.*, k.cap, k.kg_base,
       CASE WHEN k.kg_base > k.cap THEN CAST(b.u_base * k.cap / k.kg_base AS INTEGER)
            ELSE b.u_base END AS u1
FROM b JOIN k ON k.id_ruta = b.id_ruta;

-- Etapa 2: con el espacio que queda se agrega el stock de seguridad (factor FS),
-- partiendo por los productos que valen más por kilo hasta llenar el furgón.
-- No es el óptimo exacto, pero es fácil de seguir y de revisar.
DROP TABLE IF EXISTS temp.etapa2;
CREATE TEMP TABLE etapa2 AS
WITH libre AS (
    SELECT id_ruta, cap - SUM(u1 * peso_kg) AS kg_libre FROM etapa1 GROUP BY id_ruta, cap),
x AS (
    SELECT e.*, (e.u_seg - e.u1) AS extra, l.kg_libre,
           SUM((e.u_seg - e.u1) * e.peso_kg) OVER (
               PARTITION BY e.id_ruta
               ORDER BY e.precio_lista / e.peso_kg DESC, e.sku
               ROWS UNBOUNDED PRECEDING) AS kg_acum
    FROM etapa1 e JOIN libre l ON l.id_ruta = e.id_ruta)
SELECT id_ruta, fecha_ruta, sku,
       u1 + CASE
              WHEN extra <= 0                              THEN 0
              WHEN kg_acum <= kg_libre                     THEN extra
              WHEN kg_acum - extra * peso_kg < kg_libre
                   THEN CAST((kg_libre - (kg_acum - extra * peso_kg)) / peso_kg AS INTEGER)
              ELSE 0
            END AS unidades
FROM x;

-- 5. Guardar el plan
BEGIN TRANSACTION;

DELETE FROM plan_carga
WHERE estado = 'SUGERIDO'
  AND (id_ruta, fecha_ruta) IN (SELECT id_ruta, fecha_ruta FROM prox_ruta);

INSERT INTO plan_carga (id_ruta, fecha_ruta)
SELECT pr.id_ruta, pr.fecha_ruta
FROM prox_ruta pr
WHERE NOT EXISTS (SELECT 1 FROM plan_carga pc
                  WHERE pc.id_ruta = pr.id_ruta AND pc.fecha_ruta = pr.fecha_ruta);

INSERT INTO plan_carga_detalle (id_plan, sku, unidades_sugeridas)
SELECT pc.id_plan, e.sku, e.unidades
FROM etapa2 e
JOIN plan_carga pc ON pc.id_ruta = e.id_ruta AND pc.fecha_ruta = e.fecha_ruta
WHERE pc.estado = 'SUGERIDO' AND e.unidades > 0;

INSERT INTO plan_visita (id_plan, id_cliente)
SELECT pc.id_plan, cp.id_cliente
FROM cli_programados cp
JOIN plan_carga pc ON pc.id_ruta = cp.id_ruta AND pc.fecha_ruta = cp.fecha_ruta
WHERE pc.estado = 'SUGERIDO';

-- 6. Alertas: clientes que están comprando menos que antes (RF9)
WITH p AS (
    SELECT c.fecha_corte,
           (SELECT valor FROM parametro WHERE clave = 'SEMANAS_VENTANA_RECIENTE')  AS rec,
           (SELECT valor FROM parametro WHERE clave = 'SEMANAS_VENTANA_HISTORICA') AS hist,
           (SELECT valor FROM parametro WHERE clave = 'UMBRAL_CAIDA_FRECUENCIA')   AS umb
    FROM ctx c),
lim AS (
    SELECT fecha_corte, rec, hist, umb,
           date(fecha_corte, '-' || CAST(rec * 7 AS INTEGER) || ' days')          AS ini_rec,
           date(fecha_corte, '-' || CAST((rec + hist) * 7 AS INTEGER) || ' days') AS ini_hist
    FROM p),
f AS (
    SELECT c.id_cliente, l.umb, l.fecha_corte,
           SUM(vi.resultado = 'VENTA' AND vi.fecha > l.ini_hist AND vi.fecha <= l.ini_rec) / l.hist AS h,
           SUM(vi.resultado = 'VENTA' AND vi.fecha > l.ini_rec  AND vi.fecha <= l.fecha_corte) / l.rec AS r
    FROM cliente c
    JOIN visita vi ON vi.id_cliente = c.id_cliente, lim l
    WHERE c.activo = 1 AND c.fecha_alta <= l.ini_hist
    GROUP BY c.id_cliente, l.umb, l.fecha_corte, l.hist, l.rec)
INSERT OR IGNORE INTO alerta_cliente (id_cliente, fecha_alerta, compras_sem_historico, compras_sem_reciente)
SELECT id_cliente, fecha_corte, ROUND(h, 3), ROUND(r, 3)
FROM f
WHERE h > 0 AND r < umb * h
  AND NOT EXISTS (SELECT 1 FROM alerta_cliente a  -- si ya tiene una alerta abierta no se crea otra
                  WHERE a.id_cliente = f.id_cliente AND a.estado = 'ABIERTA');

COMMIT;

-- 7. Resumen
-- kg_demanda es lo que habría que cargar si el furgón no tuviera límite (demanda x factor de seguridad)
.headers on
.mode column
WITH ideal AS (SELECT id_ruta, ROUND(SUM(u_seg * peso_kg), 1) AS kg_demanda FROM etapa1 GROUP BY id_ruta)
SELECT pc.id_ruta,
       pc.fecha_ruta,
       (SELECT COUNT(*) FROM plan_visita pv WHERE pv.id_plan = pc.id_plan) AS clientes,
       SUM(d.unidades_sugeridas)                                    AS unidades,
       i.kg_demanda,
       ROUND(SUM(d.unidades_sugeridas * p.peso_kg), 1)              AS kg_plan,
       v.capacidad_kg                                               AS kg_capacidad,
       ROUND(100.0 * SUM(d.unidades_sugeridas * p.peso_kg) / v.capacidad_kg, 1) AS pct_uso
FROM plan_carga pc
JOIN plan_carga_detalle d ON d.id_plan = pc.id_plan
JOIN producto p ON p.sku = d.sku
JOIN ruta r     ON r.id_ruta = pc.id_ruta
JOIN vehiculo v ON v.id_vehiculo = r.id_vehiculo
LEFT JOIN ideal i ON i.id_ruta = pc.id_ruta
WHERE (pc.id_ruta, pc.fecha_ruta) IN (SELECT id_ruta, fecha_ruta FROM prox_ruta)
GROUP BY pc.id_plan
ORDER BY pc.fecha_ruta;

SELECT COUNT(*) AS alertas_abiertas FROM alerta_cliente WHERE estado = 'ABIERTA';
