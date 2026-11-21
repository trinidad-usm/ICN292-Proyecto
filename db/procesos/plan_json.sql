-- Saca los planes SUGERIDO (hoja de ruta y carga por familia) y las alertas abiertas
-- en un solo JSON, que después lee un nodo Code de n8n para armar el correo.
-- Tarea "Publicar hoja de ruta y orden de carga" del BPMN.
--     sqlite3 -noheader -list db/alimentos_emy.db < db/procesos/plan_json.sql
WITH carga AS (
    SELECT pc.id_plan, f.nombre AS familia,
           SUM(d.unidades_sugeridas) AS unidades,
           ROUND(SUM(d.unidades_sugeridas * p.peso_kg), 1) AS kg
    FROM plan_carga pc
    JOIN plan_carga_detalle d ON d.id_plan = pc.id_plan
    JOIN producto p ON p.sku = d.sku
    JOIN familia_producto f ON f.id_familia = p.id_familia
    WHERE pc.estado = 'SUGERIDO'
    GROUP BY pc.id_plan, f.id_familia),
visitas AS (
    SELECT pv.id_plan, rc.orden_visita, c.id_cliente, c.nombre_fantasia
    FROM plan_visita pv
    JOIN plan_carga pc   ON pc.id_plan = pv.id_plan
    JOIN ruta_cliente rc ON rc.id_ruta = pc.id_ruta AND rc.id_cliente = pv.id_cliente
    JOIN cliente c       ON c.id_cliente = pv.id_cliente)
SELECT json_object(
  'generado', datetime('now', 'localtime'),
  'planes', (
    SELECT json_group_array(json(x.obj)) FROM (
      SELECT json_object(
               'id_ruta', pc.id_ruta,
               'ruta', r.nombre,
               'fecha', pc.fecha_ruta,
               'capacidad_kg', v.capacidad_kg,
               'kg_plan', (SELECT ROUND(SUM(kg), 1) FROM carga WHERE carga.id_plan = pc.id_plan),
               'carga', (SELECT json_group_array(json_object('familia', familia, 'unidades', unidades, 'kg', kg))
                           FROM (SELECT * FROM carga WHERE carga.id_plan = pc.id_plan ORDER BY kg DESC)),
               'visitas', (SELECT json_group_array(json_object('orden', orden_visita, 'cliente', id_cliente,
                                                               'nombre', nombre_fantasia))
                             FROM (SELECT * FROM visitas WHERE visitas.id_plan = pc.id_plan
                                   ORDER BY orden_visita))
             ) AS obj
      FROM plan_carga pc
      JOIN ruta r     ON r.id_ruta = pc.id_ruta
      JOIN vehiculo v ON v.id_vehiculo = r.id_vehiculo
      WHERE pc.estado = 'SUGERIDO'
      ORDER BY pc.fecha_ruta) x),
  'alertas', (
    SELECT json_group_array(json_object('cliente', a.id_cliente, 'zona', z.nombre,
                                        'compras_sem_hist', a.compras_sem_historico,
                                        'compras_sem_rec', a.compras_sem_reciente))
    FROM alerta_cliente a
    JOIN cliente c ON c.id_cliente = a.id_cliente
    JOIN zona z    ON z.id_zona = c.id_zona
    WHERE a.estado = 'ABIERTA')
);
