# Declaración de uso de Inteligencia Artificial — Entrega 2

> Política del curso: la IA sólo puede usarse como apoyo **declarado**. Está prohibido generar datos o capturas falsas y entregar código no ejecutado por el equipo. Esta declaración debe ser **revisada, completada y firmada por el equipo** antes de la entrega.

## 1. Herramienta utilizada

| Herramienta | Proveedor | Período de uso |
|---|---|---|
| Claude (asistente de IA) | Anthropic | Noviembre 2026 |
| _(agregar otras si se usaron)_ | | |

## 2. Para qué se usó

| Producto | Uso de la IA | Qué hizo / verificó el equipo |
|---|---|---|
| `db/schema.sql` | Propuesta de DDL a partir del modelo E1 y de las decisiones de normalización | _(completar: revisión del modelo, ejecución en el PC de cada integrante)_ |
| `scripts/generar_seed.py` → `db/seed.sql` | Programa generador de datos **sintéticos**, calibrado con las magnitudes declaradas por el dueño en la E1 | _(completar)_ |
| `db/consultas.sql` y `db/procesos/*.sql` | Redacción de consultas y del algoritmo de plan semanal | _(completar: ejecución y contraste con `db/resultados/`)_ |
| `automatizacion/n8n_plan_semanal_emy.json` | Diseño del flujo y código de los nodos *Code* | _(completar: importación y ejecución en n8n del equipo)_ |
| BPMN y diagrama ER | Generación del archivo `.bpmn` y del ER a partir del esquema | _(completar)_ |
| `docs/*.md`, informe y presentación | Redacción de borradores | _(completar: edición final del equipo)_ |

## 3. Qué NO hizo la IA
- No inventó datos de la PYME: los datos del caso (problema, metas, rutas, 45 clientes) provienen del levantamiento con el dueño en la E1. Los datos transaccionales del repositorio son **sintéticos y están declarados como tales** en el `README.md` y en el informe.
- No se publicaron datos personales reales de clientes (Ley 21.719).
- Ningún resultado citado en el informe se escribió a mano: todos salen de ejecutar los scripts (`db/resultados/`).

## 4. Verificación del equipo (completar antes de entregar)

| Integrante | Clonó el repo y ejecutó el README en su PC (S/N) | Fecha | Sistema operativo |
|---|---|---|---|
| Felipe Salazar | | | |
| Martín Barra | | | |
| Montserratt Rojas | | | |
| Ignacia Álvarez | | | |
| Trinidad Salinas | | | |

Cada integrante declara entender el código entregado y poder explicarlo en la defensa.
