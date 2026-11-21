# 04. Diseño SQL y consultas de negocio

Motor: SQLite 3 (>= 3.38), Base: `db/alimentos_emy.db` (se genera, no se versiona).

## 1. Scripts

| Archivo | Qué hace | Cuándo se ejecuta |
|---|---|---|
| `db/schema.sql` | Crea 15 tablas + tabla de paso, PK/FK (incluida una FK compuesta), 30+ restricciones `CHECK`/`UNIQUE`/`NOT NULL`, 2 triggers de reglas de negocio, 5 índices y la vista `v_linea_venta`. Re-ejecutable (`DROP … IF EXISTS`). | Una vez (o para reiniciar) |
| `db/seed.sql` | Carga datos sintéticos anonimizados: 6 parámetros, 4 zonas, 45 clientes, 7 familias, 21 SKU, 1 furgón, 4 rutas, 2 742 visitas, 2 309 ventas y 16 945 líneas (2025-01-01 a 2026-11-14). Todo en una transacción. | Después de `schema.sql` |
| `db/procesos/generar_plan_semanal.sql` | Proceso del SIG: clientes a visitar, demanda, plan de carga con capacidad, alertas | Cada domingo (n8n) |
| `db/consultas.sql` | 7 consultas de negocio Q1-Q7 | A demanda |
| `db/procesos/importar_ventas_bicom.sql` | Importación incremental del CSV de Bicom | Cada domingo (n8n) |

Orden de ejecución y comandos: ver `README.md`, sección 1. Salida de referencia completa: `db/resultados/resultados_consultas.txt`.

### Verificación de restricciones
Además de cargar los datos, el esquema rechaza datos inválidos. Pruebas realizadas (cada una devuelve error y no inserta):

```sql
-- R1: venta sobre una visita sin resultado VENTA        -> "R1: la visita asociada no tiene resultado VENTA"
-- R2: visita anterior al alta del cliente               -> "R2: visita anterior a la fecha de alta del cliente"
-- R3: visita a un cliente en una ruta que no es la suya -> FOREIGN KEY constraint failed
-- R4: despachar más de lo solicitado                    -> CHECK constraint failed
-- R5: cliente con nombre real en vez de seudónimo CLI-### -> CHECK constraint failed (Ley 21.719)
```
El script de estas pruebas está en `db/resultados/pruebas_restricciones.sql` y su salida en `db/resultados/pruebas_restricciones.txt`.

## 2. Algoritmo del plan semanal (`generar_plan_semanal.sql`)

1. Fecha de corte: la última fecha con visitas, no la fecha del computador (así siempre da lo mismo).
2. Próxima fecha de cada ruta según su `dia_semana`.
3. Clientes programados (RF4): semanales siempre; quincenales si pasaron >= 11 días desde su última compra; mensuales si pasaron >= 25. Como se cuenta desde la última compra y no desde la última visita, si una visita falla el cliente vuelve a aparecer solo.
4. Demanda esperada (RF2): unidades solicitadas por SKU en las últimas 12 semanas / visitas del cliente en ese período (incluye visitas sin venta, para no sobreestimar).
5. Plan de carga con capacidad (RF5-RF6): (a) demanda base redondeada hacia arriba; si excede la capacidad, se escala proporcionalmente; (b) la capacidad sobrante se llena con el stock de seguridad (+10 %) priorizando los SKU de mayor valor por kg (no da el óptimo exacto, pero es fácil de revisar).
6. Alertas (RF9): cliente con compras/semana de las últimas 8 semanas < 60 % de su promedio de las 26 semanas anteriores.

Salida del proceso con los datos del seed:

```text
id_ruta  fecha_ruta  clientes  unidades  kg_demanda  kg_plan  kg_capacidad  pct_uso
-------  ----------  --------  --------  ----------  -------  ------------  -------
R-LUN    2026-11-16  10        301       503.7       478.5    480.0         99.7   
R-MIE    2026-11-18  9         281       583.8       479.7    480.0         99.9   
R-VIE    2026-11-20  6         336       556.5       479.9    480.0         100.0  
R-SAB    2026-11-21  8         217       243.9       243.9    480.0         50.8   
alertas_abiertas
----------------
7
```

## 3. Resultados de las consultas e interpretación

> Ojo: los datos son sintéticos (armados con los números que nos dio el dueño). Las interpretaciones sirven para mostrar qué decisiones se pueden tomar con el SIG, no son conclusiones reales sobre la empresa. Con la exportación real de Bicom, las mismas consultas darían los números reales.

### Q1: ¿Se cumple la meta de +30 % interanual? (RF8)
```text
== Q1. Cumplimiento meta de crecimiento interanual 2026 (CLP netos) ==
mes  venta_2025  venta_2026  meta_2026  crec_pct  cumpl_meta_pct  estado   
---  ----------  ----------  ---------  --------  --------------  ---------
1    12375640    17067950    16088332   37.9      106.1           CUMPLE   
2    10957540    14442350    14244802   31.8      101.4           CUMPLE   
3    9810170     11800850    12753221   20.3      92.5            NO CUMPLE
4    9330660     12481950    12129858   33.8      102.9           CUMPLE   
5    9738740     13069000    12660362   34.2      103.2           CUMPLE   
6    8461020     10007300    10999326   18.3      91.0            NO CUMPLE
7    7575700     8767900     9848410    15.7      89.0            NO CUMPLE
8    9819540     11822700    12765402   20.4      92.6            NO CUMPLE
9    12066490    14677550    15686437   21.6      93.6            NO CUMPLE
10   12957430    16042750    16844659   23.8      95.2            NO CUMPLE
```
Interpretación: La meta se cumple en enero, febrero, abril y mayo, y se pierde en marzo y desde junio en adelante; el peor mes es julio (89 % de la meta, +15,7 % de crecimiento en vez de +30 %). Es lo mismo que nos contó el dueño: el problema está en la temporada baja. La diferencia es que ahora queda medido mes a mes. Este mismo cálculo le llega por correo el día 1 de cada mes (n8n).

### Q2: Nivel de servicio (*fill rate*) y venta perdida por familia, 2026
```text
== Q2. Fill rate y venta perdida por familia de producto, 2026 ==
familia            fill_baja_pct  fill_alta_pct  venta_perdida_clp
-----------------  -------------  -------------  -----------------
Leches             94.0           94.8           2048400          
Quesos laminados   94.9           96.8           1454100          
Yoghurt y postres  94.2           95.7           872800           
Quesos en trozo    93.7           95.3           781600           
Huevos             93.4           96.9           759000           
Abarrotes          94.7           96.7           574000           
Mantequillas       94.8           97.7           537200
```
Interpretación: El *fill rate* es de 93-98 % y en todas las familias es más bajo en temporada baja. O sea, en los meses en que más cuesta vender, el furgón sale con productos que no calzan con lo que piden. Las unidades pedidas que no se pudieron despachar suman aprox. $7,0 millones en 2026; Leches concentra la mayor pérdida ($2,0 M). En la E1 este KPI no se medía; ahora se puede calcular porque guardamos lo solicitado y lo despachado.

### Q3: Plan de carga sugerido para la próxima semana (RF5, RF6)
```text
== Q3. Plan de carga sugerido (próxima semana) por ruta y familia ==
id_ruta  fecha_ruta  familia            unidades  kg   
-------  ----------  -----------------  --------  -----
R-LUN    2026-11-16  Leches             23        289.8
R-LUN    2026-11-16  Yoghurt y postres  70        56.0 
R-LUN    2026-11-16  Abarrotes          70        47.0 
R-LUN    2026-11-16  Huevos             23        39.3 
R-LUN    2026-11-16  Quesos laminados   56        22.0 
R-LUN    2026-11-16  Quesos en trozo    13        13.0 
R-LUN    2026-11-16  Mantequillas       46        11.5 
R-MIE    2026-11-18  Leches             23        289.8
R-MIE    2026-11-18  Yoghurt y postres  47        47.5 
R-MIE    2026-11-18  Abarrotes          55        43.4 
R-MIE    2026-11-18  Huevos             27        39.0 
R-MIE    2026-11-18  Quesos laminados   71        35.0 
R-MIE    2026-11-18  Quesos en trozo    14        14.0 
R-MIE    2026-11-18  Mantequillas       44        11.0 
R-VIE    2026-11-20  Leches             22        277.2
R-VIE    2026-11-20  Abarrotes          64        53.6 
R-VIE    2026-11-20  Quesos laminados   107       46.8 
R-VIE    2026-11-20  Yoghurt y postres  50        38.3 
R-VIE    2026-11-20  Huevos             26        31.6 
R-VIE    2026-11-20  Quesos en trozo    21        21.0 
R-VIE    2026-11-20  Mantequillas       46        11.5 
R-SAB    2026-11-21  Leches             7         88.2 
R-SAB    2026-11-21  Abarrotes          57        46.6 
R-SAB    2026-11-21  Yoghurt y postres  32        34.6 
R-SAB    2026-11-21  Quesos laminados   52        27.5 
R-SAB    2026-11-21  Huevos             18        24.5 
R-SAB    2026-11-21  Quesos en trozo    13        13.0 
R-SAB    2026-11-21  Mantequillas       38        9.5
```

```text
-- Q3b. Uso de capacidad del vehículo por ruta (demanda base vs. plan) --
id_ruta  fecha_ruta  clientes  kg_plan  capacidad_kg  uso_pct
-------  ----------  --------  -------  ------------  -------
R-LUN    2026-11-16  10        478.5    480.0         99.7   
R-MIE    2026-11-18  9         479.7    480.0         99.9   
R-VIE    2026-11-20  6         479.9    480.0         100.0  
R-SAB    2026-11-21  8         243.9    480.0         50.8
```
Interpretación: Es la "orden de carga" que reemplaza al *planner* de papel. Se ven dos cosas: (1) Leches pesa ~60 % de la carga de las rutas de lunes a viernes, por lo que es la familia que define la restricción de capacidad; (2) lunes, miércoles y viernes quedan al ~100 % del furgón (la demanda ideal de 504-584 kg se recorta a 480 kg), mientras el sábado usa solo 51 %. Con esto el dueño podría pasar algunos clientes al sábado en vez de dejar pedidos sin atender.

### Q4: Hoja de ruta de la próxima semana (RF4, RF7, RF10)
```text
== Q4. Hoja de ruta de la próxima semana (orden de visita) ==
fecha_ruta  id_ruta  orden_visita  id_cliente  nombre_fantasia  frecuencia_visita  ultima_compra  aviso 
----------  -------  ------------  ----------  ---------------  -----------------  -------------  ------
2026-11-16  R-LUN    1             CLI-006     Cliente Z01-006  QUINCENAL          2026-11-02     ALERTA
2026-11-16  R-LUN    2             CLI-009     Cliente Z01-009  SEMANAL            2026-11-09           
2026-11-16  R-LUN    3             CLI-007     Cliente Z01-007  QUINCENAL          2026-08-31     ALERTA
2026-11-16  R-LUN    4             CLI-012     Cliente Z01-012  QUINCENAL          2026-11-02           
2026-11-16  R-LUN    6             CLI-010     Cliente Z01-010  QUINCENAL          2026-11-02           
2026-11-16  R-LUN    7             CLI-002     Cliente Z01-002  SEMANAL            2026-11-09           
2026-11-16  R-LUN    9             CLI-003     Cliente Z01-003  SEMANAL            2026-11-09           
2026-11-16  R-LUN    12            CLI-014     Cliente Z01-014  SEMANAL            2026-11-09           
2026-11-16  R-LUN    13            CLI-008     Cliente Z01-008  SEMANAL            2026-11-09           
2026-11-16  R-LUN    14            CLI-004     Cliente Z01-004  SEMANAL            2026-11-09           
2026-11-18  R-MIE    1             CLI-030     Cliente Z03-030  QUINCENAL          2026-11-04           
2026-11-18  R-MIE    2             CLI-028     Cliente Z03-028  SEMANAL            2026-11-11           
2026-11-18  R-MIE    3             CLI-036     Cliente Z03-036  MENSUAL            2026-10-07     ALERTA
2026-11-18  R-MIE    5             CLI-026     Cliente Z03-026  QUINCENAL          2026-11-04           
2026-11-18  R-MIE    6             CLI-027     Cliente Z03-027  SEMANAL            2026-11-11           
2026-11-18  R-MIE    7             CLI-029     Cliente Z03-029  SEMANAL            2026-11-11           
2026-11-18  R-MIE    8             CLI-032     Cliente Z03-032  SEMANAL            2026-11-11           
2026-11-18  R-MIE    9             CLI-033     Cliente Z03-033  SEMANAL            2026-11-04     ALERTA
2026-11-18  R-MIE    11            CLI-034     Cliente Z03-034  SEMANAL            2026-11-11           
2026-11-20  R-VIE    3             CLI-045     Cliente Z04-045  SEMANAL            2026-11-13           
2026-11-20  R-VIE    4             CLI-041     Cliente Z04-041  SEMANAL            2026-11-13           
2026-11-20  R-VIE    5             CLI-042     Cliente Z04-042  QUINCENAL          2026-10-23           
2026-11-20  R-VIE    6             CLI-039     Cliente Z04-039  MENSUAL            2026-10-16           
2026-11-20  R-VIE    7             CLI-038     Cliente Z04-038  MENSUAL            2026-09-25     ALERTA
2026-11-20  R-VIE    8             CLI-044     Cliente Z04-044  SEMANAL            2026-11-13           
2026-11-21  R-SAB    1             CLI-016     Cliente Z02-016  SEMANAL            2026-11-14           
2026-11-21  R-SAB    2             CLI-022     Cliente Z02-022  SEMANAL            2026-11-07           
2026-11-21  R-SAB    4             CLI-017     Cliente Z02-017  SEMANAL            2026-11-14           
2026-11-21  R-SAB    5             CLI-015     Cliente Z02-015  QUINCENAL          2026-10-31     ALERTA
2026-11-21  R-SAB    6             CLI-024     Cliente Z02-024  SEMANAL            2026-11-14           
2026-11-21  R-SAB    7             CLI-020     Cliente Z02-020  SEMANAL            2026-11-14           
2026-11-21  R-SAB    9             CLI-018     Cliente Z02-018  QUINCENAL          2026-11-07           
2026-11-21  R-SAB    11            CLI-019     Cliente Z02-019  QUINCENAL          2026-09-05     ALERTA
```
Interpretación: 33 visitas programadas en 4 rutas, en el orden fijo de cada ruta. Los clientes con `ALERTA` vienen marcados para que quien maneje (el dueño o un tercero) les dedique una conversación comercial. Con esta tabla otra persona podría hacer la ruta sin tener que preguntarle todo al dueño.

### Q5: Clientes en riesgo de fuga (RF9)
```text
== Q5. Alertas abiertas de caída de frecuencia y venta en riesgo ==
id_cliente  zona                   frecuencia_visita  compras_sem_hist  compras_sem_rec  variacion_pct  venta_mensual_hist_clp
----------  ---------------------  -----------------  ----------------  ---------------  -------------  ----------------------
CLI-038     Doñihue-Olivar         MENSUAL            0.231             0.125            -46.0          367092                
CLI-015     Rancagua Sur           QUINCENAL          0.5               0.25             -50.0          233667                
CLI-033     Machalí                SEMANAL            0.885             0.125            -86.0          199183                
CLI-036     Machalí                MENSUAL            0.231             0.125            -46.0          192683                
CLI-006     Rancagua Centro-Norte  QUINCENAL          0.462             0.25             -46.0          188092                
CLI-007     Rancagua Centro-Norte  QUINCENAL          0.308             0.0              -100.0         159817                
CLI-019     Rancagua Sur           QUINCENAL          0.308             0.0              -100.0         134833
```
Interpretación: 7 clientes compran hoy menos del 60 % de su patrón histórico. Sumando su venta mensual histórica hay aprox. $1,48 millones/mes en riesgo, entre 12 % y 17 % de la venta mensual de jun-ago 2026. El más urgente es CLI-033, que compra todas las semanas y bajó un 86 %: casi dejó de comprar.

### Q6: Efectividad de visita por ruta (últimas 12 semanas)
```text
== Q6. Efectividad de visitas por ruta (últimas 12 semanas) ==
id_ruta  zona                   visitas  jornadas  visitas_x_jornada  efectividad_pct  sin_reposicion  ausente  sin_saldo  venta_x_jornada_clp
-------  ---------------------  -------  --------  -----------------  ---------------  --------------  -------  ---------  -------------------
R-LUN    Rancagua Centro-Norte  114      12        9.5                84.2             7               10       1          1063704            
R-MIE    Machalí                96       12        8.0                81.3             6               10       2          917391             
R-VIE    Doñihue-Olivar         57       12        4.8                82.5             3               5        2          786362             
R-SAB    Rancagua Sur           93       12        7.8                81.7             9               3        5          746154
```
Interpretación: Entre 81 % y 84 % de las visitas termina en venta: 1 de cada 6 viajes a un cliente no vende. En lunes y miércoles la causa principal es "ausente" (local cerrado), un problema de coordinación que podría reducirse avisando por WhatsApp antes de la visita. La ruta del viernes (Doñihue-Olivar) visita solo 4,8 clientes por jornada: es la primera que habría que revisar por el gasto en combustible por cada venta.

### Q7: ¿Dónde se explica el incumplimiento de la temporada baja?
```text
== Q7. Crecimiento temporada baja (jun-ago) 2026 vs 2025 por zona ==
zona                   venta_2025  venta_2026  crec_pct
---------------------  ----------  ----------  --------
Rancagua Sur           5542010     6121000     10.4    
Rancagua Centro-Norte  8580010     10181700    18.7    
Doñihue-Olivar         5601660     6783700     21.1    
Machalí                6132580     7511500     22.5
```

```text
-- Q7b. Mismo análisis por familia --
familia            venta_2025  venta_2026  crec_pct
-----------------  ----------  ----------  --------
Leches             6872670     7749600     12.8    
Quesos laminados   6149680     7087900     15.3    
Mantequillas       2631280     3044400     15.7    
Quesos en trozo    2573670     2988400     16.1    
Abarrotes          2281840     2771800     21.5    
Huevos             2689720     3478200     29.3    
Yoghurt y postres  2657400     3477600     30.9
```
Interpretación: El crecimiento de jun-ago 2026 es más bajo en Rancagua Sur (+10,4 %) y en el núcleo lácteo (Leches +12,8 %, quesos laminados +15,3 %), mientras huevos y yoghurt sí crecen ~30 %. La brecha no está repartida pareja: se concentra en una zona y en algunas familias, y ahí habría que poner el esfuerzo el próximo invierno.

## 4. Cómo se responde cada pregunta de negocio

| Pregunta del dueño | Consulta | Decisión que habilita |
|---|---|---|
| ¿Voy a llegar a la meta este mes? | Q1 | Reaccionar antes de cerrar el mes |
| ¿Qué me falta en el camión? | Q2 | Ajustar el mix por familia |
| ¿Qué cargo el lunes? | Q3 | Cargar sin improvisar y sin exceder el furgón |
| ¿A quién visito y en qué orden? | Q4 | Delegar la ruta |
| ¿Qué clientes estoy perdiendo? | Q5 | Retener antes de perder |
| ¿Qué rutas rinden menos? | Q6 | Reordenar rutas / coordinar visitas |
| ¿Dónde está la brecha de la temporada baja? | Q7 | Foco comercial por zona y familia |
