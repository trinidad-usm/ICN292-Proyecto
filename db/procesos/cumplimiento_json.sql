-- Cumplimiento de la meta de +30 % (RF8), para el correo mensual de n8n.
-- Compara la venta de los últimos 12 meses completos con el mismo mes del año anterior
-- y lo entrega en JSON. Es la tarea mensual "Calcular cumplimiento de meta +30 %" del BPMN.
--     sqlite3 -noheader -list db/alimentos_emy.db < db/procesos/cumplimiento_json.sql
WITH corte AS (SELECT date(MAX(fecha), 'start of month') AS ini_mes_corte FROM visita),
meta AS (SELECT valor AS pct FROM parametro WHERE clave = 'META_CRECIMIENTO_INTERANUAL'),
mensual AS (
    SELECT strftime('%Y-%m', fecha) AS periodo, SUM(monto_neto) AS venta
    FROM v_linea_venta GROUP BY 1),
filas AS (
    SELECT a.periodo,
           a.venta                                   AS venta_actual,
           b.venta                                   AS venta_anio_anterior,
           ROUND(100.0 * a.venta / (b.venta * (1 + m.pct)), 1) AS cumplimiento_pct
    FROM mensual a
    JOIN mensual b ON b.periodo = strftime('%Y-%m', date(a.periodo || '-01', '-1 year'))
    CROSS JOIN meta m CROSS JOIN corte c
    WHERE a.periodo || '-01' <  c.ini_mes_corte
      AND a.periodo || '-01' >= date(c.ini_mes_corte, '-12 months'))
SELECT json_object(
         'meta_pct', (SELECT pct * 100 FROM meta),
         'meses', (SELECT json_group_array(json_object(
                       'periodo', periodo,
                       'venta_actual', venta_actual,
                       'venta_anio_anterior', venta_anio_anterior,
                       'cumplimiento_pct', cumplimiento_pct,
                       'estado', CASE WHEN cumplimiento_pct >= 100 THEN 'CUMPLE' ELSE 'NO CUMPLE' END))
                   FROM (SELECT * FROM filas ORDER BY periodo)));
