-- Importar ventas desde Bicom (RF1). Tarea "Importar ventas exportadas desde Bicom" del BPMN.
-- Carga el CSV que se exporta de Bicom en una tabla de paso (stg_venta_bicom) y desde ahí
-- llena visita, venta y detalle_venta.
--
-- Hay que correrlo desde la carpeta del repo, porque lee data/entrada/export_bicom.csv
-- (para probar, copiar ahí data/samples/export_bicom_ejemplo.csv):
--     sqlite3 db/alimentos_emy.db < db/procesos/importar_ventas_bicom.sql
-- Columnas del CSV (con encabezado):
--     folio,fecha,id_cliente,sku,cantidad,precio_unitario,tipo_documento,medio_pago
-- Si un folio ya está cargado no se carga de nuevo.
-- Bicom solo trae lo despachado, así que suponemos cantidad_solicitada = cantidad.

PRAGMA foreign_keys = ON;
.bail on

DELETE FROM stg_venta_bicom;
.import --csv --skip 1 data/entrada/export_bicom.csv stg_venta_bicom

.headers on
.mode column
.print '-- Filas rechazadas (cliente o SKU inexistente en el SIG): --'
SELECT s.folio, s.fecha, s.id_cliente, s.sku,
       CASE WHEN c.id_cliente IS NULL THEN 'cliente desconocido' ELSE 'sku desconocido' END AS motivo
FROM stg_venta_bicom s
LEFT JOIN cliente  c ON c.id_cliente = s.id_cliente
LEFT JOIN producto p ON p.sku = s.sku
WHERE c.id_cliente IS NULL OR p.sku IS NULL;

BEGIN TRANSACTION;

-- 1) Una visita por cliente y fecha, en la ruta del cliente que cae ese día de la semana
WITH s AS (
    SELECT DISTINCT id_cliente, fecha,
           (CAST(strftime('%w', fecha) AS INTEGER) + 6) % 7 + 1 AS dia_iso
    FROM stg_venta_bicom
    WHERE id_cliente IN (SELECT id_cliente FROM cliente)),
cand AS (
    SELECT s.id_cliente, s.fecha, rc.id_ruta,
           ROW_NUMBER() OVER (PARTITION BY s.id_cliente, s.fecha
                              ORDER BY (r.dia_semana = s.dia_iso) DESC, rc.id_ruta) AS rn
    FROM s
    JOIN ruta_cliente rc ON rc.id_cliente = s.id_cliente
    JOIN ruta r          ON r.id_ruta = rc.id_ruta)
INSERT INTO visita (id_ruta, id_cliente, fecha, resultado)
SELECT id_ruta, id_cliente, fecha, 'VENTA'
FROM cand
WHERE rn = 1
  AND NOT EXISTS (SELECT 1 FROM visita v WHERE v.id_cliente = cand.id_cliente AND v.fecha = cand.fecha);

-- Si ya había una visita sin venta pero llegó una boleta/factura, se cambia a VENTA
UPDATE visita SET resultado = 'VENTA'
WHERE resultado <> 'VENTA'
  AND EXISTS (SELECT 1 FROM stg_venta_bicom s
               WHERE s.id_cliente = visita.id_cliente AND s.fecha = visita.fecha);

-- 2) La venta (un documento por visita)
INSERT INTO venta (id_visita, folio_bicom, tipo_documento, medio_pago)
SELECT v.id_visita, s.folio, MAX(s.tipo_documento), MAX(s.medio_pago)
FROM stg_venta_bicom s
JOIN visita v ON v.id_cliente = s.id_cliente AND v.fecha = s.fecha
WHERE NOT EXISTS (SELECT 1 FROM venta x WHERE x.folio_bicom = s.folio)
GROUP BY s.folio, v.id_visita;

-- 3) El detalle, producto por producto
INSERT INTO detalle_venta (id_venta, sku, cantidad_solicitada, cantidad_despachada, precio_unitario)
SELECT ve.id_venta, s.sku, SUM(s.cantidad), SUM(s.cantidad), MAX(s.precio_unitario)
FROM stg_venta_bicom s
JOIN venta ve ON ve.folio_bicom = s.folio
WHERE s.sku IN (SELECT sku FROM producto)
  AND NOT EXISTS (SELECT 1 FROM detalle_venta d WHERE d.id_venta = ve.id_venta AND d.sku = s.sku)
GROUP BY ve.id_venta, s.sku;

-- 4) Los planes de esas fechas quedan como EJECUTADO
UPDATE plan_carga SET estado = 'EJECUTADO'
WHERE fecha_ruta IN (SELECT DISTINCT fecha FROM stg_venta_bicom);

COMMIT;

.print '-- Resultado de la importación: --'
SELECT (SELECT COUNT(*) FROM stg_venta_bicom)                    AS filas_csv,
       (SELECT COUNT(DISTINCT folio) FROM stg_venta_bicom)       AS documentos_csv,
       (SELECT MAX(fecha) FROM visita)                           AS nueva_fecha_corte,
       (SELECT COUNT(*) FROM venta)                              AS ventas_totales_en_bd;
