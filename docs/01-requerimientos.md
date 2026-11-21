# 01. Requerimientos y trazabilidad a la solución

Los requerimientos son los mismos de la E1 (con prioridad MoSCoW). Lo nuevo es la columna "Dónde se cumple", que indica en qué tabla, script, consulta o nodo de n8n quedó implementado cada uno.

## Requerimientos funcionales

| # | Requisito | Prioridad | Dónde se cumple en la E2 | Estado |
|---|---|---|---|---|
| RF1 | Importar historial de ventas exportado de Bicom (CSV) | Must | `db/procesos/importar_ventas_bicom.sql`, nodo n8n *Importar ventas Bicom (RF1)*, tablas `stg_venta_bicom` → `visita`/`venta`/`detalle_venta` | Sí |
| RF2 | Calcular volumen y frecuencia de compra por cliente/familia | Must | `generar_plan_semanal.sql` paso 3 (demanda esperada por visita y SKU) | Sí |
| RF3 | Agrupar clientes por zona geográfica | Must | tablas `zona`, `cliente.id_zona`, `ruta.id_zona` | Sí |
| RF4 | Sugerir, por día de ruta, los clientes a visitar según su frecuencia | Must | `generar_plan_semanal.sql` paso 2 → tabla `plan_visita`, consulta Q4 | Sí |
| RF5 | Sugerir el mix de carga por ruta | Must | `generar_plan_semanal.sql` paso 4 → `plan_carga`, `plan_carga_detalle`, Q3 | Sí (por SKU, agregable por familia) |
| RF6 | Registrar la capacidad del vehículo como restricción | Must | `vehiculo.capacidad_kg`, escalamiento y heurística de mochila en el paso 4, Q3b | Sí |
| RF7 | Generar plan de ruta y carga exportable/imprimible | Must | `plan_json.sql` + nodo *Armar hoja de ruta (RF7)* → correo HTML legible en celular | Sí |
| RF8 | Comparar venta real mensual con la meta (+30 %) | Should | Q1, `cumplimiento_json.sql`, rama mensual del flujo n8n | Sí |
| RF9 | Identificar clientes con caída de frecuencia | Should | `generar_plan_semanal.sql` paso 6 → `alerta_cliente`, Q5 | Sí |
| RF10 | Que un tercero pueda ejecutar una ruta con el plan | Could | hoja de ruta ordenada (Q4 y correo) sin depender del criterio del dueño | Parcial, falta probarlo en terreno |

## Requerimientos no funcionales

| # | Requisito | Prioridad | Cómo se aborda en la E2 |
|---|---|---|---|
| RNF1 | Usabilidad para una persona sin formación técnica | Must | El dueño no tiene que usar la base de datos, le llega un correo con la hoja de ruta. Lo que falta: para ajustar el plan (kg o unidades) todavía hay que editar la base (ver limitaciones). |
| RNF2 | Privacidad conforme a Ley 21.719 | Must | Seudónimos `CLI-###`, zonas agregadas, datos sintéticos en el repo, `data/entrada/` en `.gitignore`, credenciales SMTP fuera del JSON de n8n |
| RNF3 | Plan generado en pocos minutos | Should | Medido: los nodos SQL del flujo tardan < 0,1 s cada uno (`automatizacion/evidencia/ejecucion_semanal.json`) |
| RNF4 | Actualizar historial sin reconfigurar | Should | Importación incremental e idempotente (folios ya cargados se ignoran); parámetros en tabla `parametro` |
| RNF5 | Plan revisable en móvil o imprimible | Should | Correo HTML de una columna (ver `docs/img/correo_semanal.png`) |
| RNF6 | Disponible los domingos en la noche | Could | Disparador n8n domingo 19:00 (zona horaria America/Santiago) |

## Reglas de negocio implementadas como restricciones

| Regla | Implementación |
|---|---|
| R1, Solo hay venta si la visita terminó en venta | trigger `trg_venta_requiere_resultado_venta` |
| R2, No se visita a un cliente antes de su fecha de alta | trigger `trg_visita_posterior_alta` |
| R3, Solo se visita a un cliente en una ruta a la que está asignado | FK compuesta `visita(id_ruta, id_cliente) → ruta_cliente` |
| R4, No se despacha más de lo solicitado | `CHECK (cantidad_despachada <= cantidad_solicitada)` |
| R5, Un cliente no puede tener dos visitas el mismo día | `UNIQUE (id_cliente, fecha)` en `visita` |
| R6, Una visita genera a lo más un documento | `UNIQUE (id_visita)` en `venta` |
| R7, Dos clientes no comparten posición en la ruta | `UNIQUE (id_ruta, orden_visita)` |
