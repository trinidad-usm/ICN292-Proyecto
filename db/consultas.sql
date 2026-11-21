-- Consultas de negocio - Alimentos Emy
-- Correr después de schema.sql, seed.sql y procesos/generar_plan_semanal.sql:
--   sqlite3 db/alimentos_emy.db ".read db/consultas.sql"
-- Lo que significa cada resultado lo explicamos en docs/04-sql-consultas.md
-- Los datos llegan hasta el 2026-11-14 (último sábado con ventas).

.headers on
.mode column
PRAGMA foreign_keys = ON;

-- Q1 (RF8): ¿en qué meses de 2026 se llegó a +30 % respecto al mismo mes de 2025?
-- Solo meses completos, por eso no aparece noviembre.
.print ''
.print '== Q1. Cumplimiento meta de crecimiento interanual 2026 (CLP netos) =='
WITH mensual AS (
    SELECT anio, mes, SUM(monto_neto) AS venta
    FROM v_linea_venta
    GROUP BY anio, mes),
meta AS (SELECT valor AS pct FROM parametro WHERE clave = 'META_CRECIMIENTO_INTERANUAL'),
corte AS (SELECT MAX(fecha) AS f FROM visita)
SELECT a.mes,
       b.venta                                        AS venta_2025,
       a.venta                                        AS venta_2026,
       CAST(ROUND(b.venta * (1 + m.pct)) AS INTEGER)  AS meta_2026,
       ROUND(100.0 * (a.venta - b.venta) / b.venta, 1) AS crec_pct,
       ROUND(100.0 * a.venta / (b.venta * (1 + m.pct)), 1) AS cumpl_meta_pct,
       CASE WHEN a.venta >= b.venta * (1 + m.pct) THEN 'CUMPLE' ELSE 'NO CUMPLE' END AS estado
FROM mensual a
JOIN mensual b ON b.mes = a.mes AND b.anio = '2025'
CROSS JOIN meta m
CROSS JOIN corte c
WHERE a.anio = '2026'
  AND a.mes < CAST(strftime('%m', c.f) AS INTEGER)
ORDER BY a.mes;

-- Q2: fill rate (despachado / solicitado) y venta perdida por familia en 2026.
-- Tomamos marzo a agosto como temporada baja.
.print ''
.print '== Q2. Fill rate y venta perdida por familia de producto, 2026 =='
SELECT f.nombre AS familia,
       ROUND(100.0 * SUM(CASE WHEN l.mes BETWEEN 3 AND 8 THEN l.cantidad_despachada END)
                   / SUM(CASE WHEN l.mes BETWEEN 3 AND 8 THEN l.cantidad_solicitada END), 1) AS fill_baja_pct,
       ROUND(100.0 * SUM(CASE WHEN l.mes NOT BETWEEN 3 AND 8 THEN l.cantidad_despachada END)
                   / SUM(CASE WHEN l.mes NOT BETWEEN 3 AND 8 THEN l.cantidad_solicitada END), 1) AS fill_alta_pct,
       SUM((l.cantidad_solicitada - l.cantidad_despachada) * l.precio_unitario) AS venta_perdida_clp
FROM v_linea_venta l
JOIN familia_producto f ON f.id_familia = l.id_familia
WHERE l.anio = '2026'
GROUP BY f.id_familia
ORDER BY venta_perdida_clp DESC;

-- Q3 (RF5, RF6, RF7): carga sugerida para la próxima semana, por ruta y familia.
-- Esto reemplaza el planner que el dueño llena a mano el domingo.
.print ''
.print '== Q3. Plan de carga sugerido (próxima semana) por ruta y familia =='
SELECT pc.id_ruta,
       pc.fecha_ruta,
       f.nombre                                  AS familia,
       SUM(d.unidades_sugeridas)                 AS unidades,
       ROUND(SUM(d.unidades_sugeridas * p.peso_kg), 1) AS kg
FROM plan_carga pc
JOIN plan_carga_detalle d ON d.id_plan = pc.id_plan
JOIN producto p           ON p.sku = d.sku
JOIN familia_producto f   ON f.id_familia = p.id_familia
WHERE pc.estado = 'SUGERIDO'
GROUP BY pc.id_plan, f.id_familia
ORDER BY pc.fecha_ruta, kg DESC;

.print ''
.print '-- Q3b. Uso de capacidad del vehículo por ruta (demanda base vs. plan) --'
SELECT pc.id_ruta,
       pc.fecha_ruta,
       (SELECT COUNT(*) FROM plan_visita pv WHERE pv.id_plan = pc.id_plan) AS clientes,
       ROUND(SUM(d.unidades_sugeridas * p.peso_kg), 1)                     AS kg_plan,
       v.capacidad_kg,
       ROUND(100.0 * SUM(d.unidades_sugeridas * p.peso_kg) / v.capacidad_kg, 1) AS uso_pct
FROM plan_carga pc
JOIN plan_carga_detalle d ON d.id_plan = pc.id_plan
JOIN producto p           ON p.sku = d.sku
JOIN ruta r               ON r.id_ruta = pc.id_ruta
JOIN vehiculo v           ON v.id_vehiculo = r.id_vehiculo
WHERE pc.estado = 'SUGERIDO'
GROUP BY pc.id_plan
ORDER BY pc.fecha_ruta;

-- Q4 (RF4, RF7, RF10): hoja de ruta con los clientes y el orden de visita.
-- Con esto otra persona puede hacer la ruta sin depender del dueño.
.print ''
.print '== Q4. Hoja de ruta de la próxima semana (orden de visita) =='
SELECT pc.fecha_ruta,
       pc.id_ruta,
       rc.orden_visita,
       c.id_cliente,
       c.nombre_fantasia,
       c.frecuencia_visita,
       (SELECT MAX(vi.fecha) FROM visita vi
         WHERE vi.id_cliente = c.id_cliente AND vi.resultado = 'VENTA') AS ultima_compra,
       CASE WHEN EXISTS (SELECT 1 FROM alerta_cliente a
                          WHERE a.id_cliente = c.id_cliente AND a.estado = 'ABIERTA')
            THEN 'ALERTA' ELSE '' END AS aviso
FROM plan_carga pc
JOIN plan_visita pv  ON pv.id_plan = pc.id_plan
JOIN ruta_cliente rc ON rc.id_ruta = pc.id_ruta AND rc.id_cliente = pv.id_cliente
JOIN cliente c       ON c.id_cliente = pv.id_cliente
WHERE pc.estado = 'SUGERIDO'
ORDER BY pc.fecha_ruta, rc.orden_visita;

-- Q5 (RF9): clientes que están comprando menos y cuánta venta al mes podríamos perder
.print ''
.print '== Q5. Alertas abiertas de caída de frecuencia y venta en riesgo =='
SELECT a.id_cliente,
       z.nombre                              AS zona,
       c.frecuencia_visita,
       a.compras_sem_historico               AS compras_sem_hist,
       a.compras_sem_reciente                AS compras_sem_rec,
       ROUND(100.0 * (a.compras_sem_reciente - a.compras_sem_historico)
                   / a.compras_sem_historico, 0) AS variacion_pct,
       (SELECT CAST(ROUND(SUM(l.monto_neto) / 6.0) AS INTEGER)
          FROM v_linea_venta l
         WHERE l.id_cliente = a.id_cliente
           AND l.fecha > date(a.fecha_alerta, '-238 days')
           AND l.fecha <= date(a.fecha_alerta, '-56 days')) AS venta_mensual_hist_clp
FROM alerta_cliente a
JOIN cliente c ON c.id_cliente = a.id_cliente
JOIN zona z    ON z.id_zona = c.id_zona
WHERE a.estado = 'ABIERTA'
ORDER BY venta_mensual_hist_clp DESC;

-- Q6: de las visitas de las últimas 12 semanas, cuántas terminan en venta
-- y por qué no se vendió en las otras.
.print ''
.print '== Q6. Efectividad de visitas por ruta (últimas 12 semanas) =='
WITH ult AS (SELECT date(MAX(fecha), '-84 days') AS desde FROM visita),
vis AS (
    SELECT vi.*, (SELECT SUM(d.cantidad_despachada * d.precio_unitario)
                    FROM venta v JOIN detalle_venta d ON d.id_venta = v.id_venta
                   WHERE v.id_visita = vi.id_visita) AS monto
    FROM visita vi, ult
    WHERE vi.fecha > ult.desde)
SELECT r.id_ruta,
       z.nombre                                            AS zona,
       COUNT(*)                                            AS visitas,
       COUNT(DISTINCT vis.fecha)                           AS jornadas,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT vis.fecha), 1) AS visitas_x_jornada,
       ROUND(100.0 * SUM(resultado = 'VENTA') / COUNT(*), 1) AS efectividad_pct,
       SUM(resultado = 'SIN_REPOSICION')                   AS sin_reposicion,
       SUM(resultado = 'AUSENTE')                          AS ausente,
       SUM(resultado = 'SIN_SALDO')                        AS sin_saldo,
       CAST(ROUND(SUM(monto) / COUNT(DISTINCT vis.fecha)) AS INTEGER) AS venta_x_jornada_clp
FROM vis
JOIN ruta r ON r.id_ruta = vis.id_ruta
JOIN zona z ON z.id_zona = r.id_zona
GROUP BY r.id_ruta
ORDER BY venta_x_jornada_clp DESC;

-- Q7: para ver dónde está el problema de la temporada baja comparamos
-- jun-ago 2026 contra jun-ago 2025, por zona y después por familia.
.print ''
.print '== Q7. Crecimiento temporada baja (jun-ago) 2026 vs 2025 por zona =='
SELECT z.nombre AS zona,
       SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END) AS venta_2025,
       SUM(CASE WHEN l.anio = '2026' THEN l.monto_neto END) AS venta_2026,
       ROUND(100.0 * (SUM(CASE WHEN l.anio = '2026' THEN l.monto_neto END)
                    - SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END))
                   / SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END), 1) AS crec_pct
FROM v_linea_venta l
JOIN zona z ON z.id_zona = l.id_zona
WHERE l.mes BETWEEN 6 AND 8
GROUP BY z.id_zona
ORDER BY crec_pct;

.print ''
.print '-- Q7b. Mismo análisis por familia --'
SELECT f.nombre AS familia,
       SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END) AS venta_2025,
       SUM(CASE WHEN l.anio = '2026' THEN l.monto_neto END) AS venta_2026,
       ROUND(100.0 * (SUM(CASE WHEN l.anio = '2026' THEN l.monto_neto END)
                    - SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END))
                   / SUM(CASE WHEN l.anio = '2025' THEN l.monto_neto END), 1) AS crec_pct
FROM v_linea_venta l
JOIN familia_producto f ON f.id_familia = l.id_familia
WHERE l.mes BETWEEN 6 AND 8
GROUP BY f.id_familia
ORDER BY crec_pct;
