-- Pruebas de las restricciones: todos estos INSERT deberían fallar.
-- Se corre con la base ya cargada (schema + seed):
--     sqlite3 db/alimentos_emy.db ".read db/resultados/pruebas_restricciones.sql"
-- Al final contamos las filas de prueba que quedaron, que tienen que ser 0.
PRAGMA foreign_keys = ON;
.bail off
.print '-- R1: venta sobre una visita cuyo resultado no es VENTA (esperado: R1 ...)'
INSERT INTO venta (id_visita, folio_bicom, tipo_documento, medio_pago)
SELECT id_visita, 'TEST-R1', 'BOLETA', 'EFECTIVO' FROM visita WHERE resultado = 'AUSENTE' LIMIT 1;
.print '-- R2: visita antes de la fecha de alta del cliente (esperado: R2 ...)'
INSERT INTO visita (id_ruta, id_cliente, fecha, resultado)
SELECT id_ruta, id_cliente, '2000-01-03', 'VENTA' FROM ruta_cliente WHERE id_cliente = 'CLI-001';
.print '-- R3: visita a un cliente en una ruta que no es la suya (esperado: FOREIGN KEY constraint failed)'
INSERT INTO visita (id_ruta, id_cliente, fecha, resultado) VALUES ('R-SAB', 'CLI-001', '2026-11-21', 'VENTA');
.print '-- R4: despachar más de lo solicitado (esperado: CHECK constraint failed)'
INSERT INTO detalle_venta (id_venta, sku, cantidad_solicitada, cantidad_despachada, precio_unitario)
VALUES ((SELECT MIN(id_venta) FROM venta), 'HU-002', 2, 5, 3000);
.print '-- R5: cliente con identificador fuera del formato seudónimo (esperado: CHECK constraint failed)'
INSERT INTO cliente (id_cliente, nombre_fantasia, tipo_negocio, id_zona, frecuencia_visita, fecha_alta)
VALUES ('Juan Pérez', 'Almacén Juan', 'ALMACEN', 'Z01', 'SEMANAL', '2026-01-01');
.print '-- Verificación: filas de prueba que quedaron en la base (esperado: 0)'
SELECT (SELECT COUNT(*) FROM venta WHERE folio_bicom = 'TEST-R1')
     + (SELECT COUNT(*) FROM visita WHERE fecha IN ('2000-01-03','2026-11-21'))
     + (SELECT COUNT(*) FROM cliente WHERE id_cliente = 'Juan Pérez') AS filas_invalidas_insertadas;
