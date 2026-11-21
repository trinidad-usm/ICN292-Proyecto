# Declaración de uso de Inteligencia Artificial - Entrega 2

Utilizamos inteligencia artificial como herramienta de apoyo durante el desarrollo del proyecto, de acuerdo con la política del curso. Su uso se limitó principalmente a resolver dudas puntuales, aclarar conceptos y apoyar algunas tareas específicas de implementación. A continuación, detallamos cómo se utilizó y qué realizó el equipo.

## 1. Herramienta utilizada

| Herramienta | Proveedor | Período de uso |
|---|---|---|
| Claude (asistente de IA) | Anthropic | Noviembre 2026 |

## 2. Para qué se usó

| Producto | Uso de la IA | Qué hizo / verificó el equipo |
|---|---|---|
| `db/schema.sql` | Consulta de dudas puntuales sobre sintaxis SQL, estructura de tablas y restricciones. | Diseñamos e implementamos el esquema de la base de datos a partir del modelo ER de la E1 y nuestras decisiones de normalización. |
| `scripts/generar_seed.py` y `db/seed.sql` | Apoyo en la generación de datos sintéticos y resolución de dudas sobre su implementación. | Definimos los criterios y parámetros de generación utilizando la información obtenida en el levantamiento con el dueño de la PYME. Revisamos la coherencia de los datos generados. |
| `db/consultas.sql` y `db/procesos/*.sql` | Consultas puntuales para resolver dudas sobre sintaxis, funciones y procedimientos SQL. | Definimos las preguntas de negocio y desarrollamos las consultas y procesos necesarios. Ejecutamos y verificamos sus resultados. |
| `automatizacion/n8n_plan_semanal_emy.json` | Resolución de dudas sobre la configuración de nodos y su funcionamiento en n8n. | Diseñamos e implementamos el flujo de automatización, revisando su correspondencia con las actividades definidas en el BPMN. |
| BPMN y diagrama ER | Consultas para aclarar aspectos de representación y estructura de los diagramas. | Elaboramos los diagramas considerando el proceso levantado con el dueño y las modificaciones realizadas respecto a la E1. |
| `README.md`, documentación e informe | Apoyo puntual en la aclaración de conceptos y revisión de redacción. | Elaboramos y revisamos la documentación, verificando que reflejara correctamente el desarrollo del proyecto. |

## 3. Qué NO hizo la IA

- No desarrolló el proyecto de manera autónoma ni tomó las decisiones de diseño e implementación. El equipo definió los requerimientos, la estructura de la base de datos, las consultas, los procesos y la lógica de automatización.
- No definió las preguntas de negocio ni los resultados esperados. Estos fueron determinados por el equipo a partir de los objetivos del proyecto.
- No inventó información de la PYME. Los datos del caso, incluyendo el problema, las metas, las rutas y los 45 clientes, provienen del levantamiento realizado con el dueño en la E1. Los datos transaccionales utilizados son sintéticos y están declarados como tales en el README y en el informe.
- No se utilizaron datos personales reales de clientes.
- Los resultados presentados en el informe se obtuvieron mediante la ejecución de los scripts desarrollados por el equipo.

**Equipo:** Felipe Salazar, Martín Barra, Montserratt Rojas, Ignacia Álvarez, Trinidad Salinas.

Cada integrante declara entender el código entregado y poder explicarlo en la defensa.
