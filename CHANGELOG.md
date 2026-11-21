# CHANGELOG: qué cambió desde la Entrega 1

Para cada cambio ponemos qué cambió y por qué. El detalle está en el archivo de `docs/` que aparece en cada sección.

## v1.0-e2 (21-11-2026), Entrega 2

### Proceso (docs/02-bpmn.md)
- Cambiado el BPMN to-be: lane "SIG (SQLite + n8n)" con tareas de servicio trazadas a nodos n8n; disparador "Domingo 19:00"; compuerta "¿Requiere ajustes?" para que el dueño apruebe el plan; evento intermedio "Día de ruta".
- Cambiado el manejo de excepciones en ruta: "Registrar incidencia (el SIG la reagenda)" reemplaza "hablar con el cliente / reagendar / venta perdida" y "resolver por improvisación".
- Agregado "Cuadrar carga devuelta vs. vendido" antes del cierre de caja (riesgo de merma detectado en el as-is).
- Agregado el BPMN en formato `.bpmn` editable (antes solo imagen de Bizagi).

### Datos (docs/03-modelo-datos.md)
- Agregada la entidad `visita` (registra visitas sin venta); `venta` deja de guardar fecha y cliente.
- Eliminado `monto_total` de la venta (atributo derivado → violaba 3FN).
- Agregados `cantidad_solicitada`, `cantidad_despachada` y `precio_unitario` en `detalle_venta` (KPI *fill rate* y precio histórico).
- Cambiado `PlanCarga`: encabezado por ruta y fecha + detalle por SKU + `plan_visita` (hoja de ruta).
- Agregadas `ruta_cliente` (resuelve N:M con `orden_visita`), `parametro`, `stg_venta_bicom` y triggers de reglas de negocio.

### SQL (docs/04-sql-consultas.md)
- Agregados `schema.sql`, `seed.sql` (sintético, reproducible), 7 consultas de negocio, scripts de proceso y pruebas negativas de restricciones.

### Automatización (docs/05-automatizacion-n8n.md)
- Agregado flujo n8n con rama semanal (plan + alertas + correo) y rama mensual (cumplimiento de meta), probado en n8n 2.x.

### Arquitectura / stack, cambios respecto de lo planificado en la E1
- Se mantiene SQLite 3 como persistencia local (sin servidor), tal como se propuso.
- Cambiado: la lógica analítica que en la E1 se planeó en Python (pandas + PuLP) se implementó en SQL dentro de los scripts de proceso. Motivo: el enunciado de la E2 exige que la solución sea auditable en el motor SQL; así cualquier ayudante la reproduce solo con `sqlite3`.
- Cambiado: en vez de optimizar con PuLP usamos un método más simple: si la carga no cabe se baja todo en la misma proporción, y el espacio que sobra se llena con los productos que valen más por kg. Es más fácil de revisar, aunque no asegura el óptimo.
- No implementado: la interfaz Streamlit y el PDF con reportlab. La salida al usuario es el correo HTML que envía n8n (cumple RF7/RNF5). Queda como trabajo futuro.
- No implementado: ruteo con distancias (orden de visita óptimo). El orden de visita es el fijo de `ruta_cliente`.

### Equipo y caso
- Sin cambios: mismo equipo de 5 integrantes y misma PYME (Alimentos Emy).
