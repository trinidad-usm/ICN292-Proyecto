# ICN-292 Proyecto SIG - Alimentos Emy (Entrega 2)

SIG para planificar las rutas y la carga del furgón de Alimentos Emy, una distribuidora mayorista de lácteos y abarrotes que atiende almacenes y minimarkets (canal tradicional) desde Olivar, Región de O'Higgins.

| | |
|---|---|
| Curso | ICN-292 Sistemas de Información para la Gestión, paralelo 101, 2026-2 |
| Equipo | Felipe Salazar, Martín Barra, Montserratt Rojas, Ignacia Álvarez, Trinidad Salinas |
| Motor SQL | SQLite 3, versión 3.38 o más nueva |
| Automatización | n8n (lo probamos en n8n 2.x instalado en local) |
| Versión que se defiende | tag `v1.0-e2` (ver `ENLACE_GITHUB.txt`) |

**Problema.** Hoy el dueño decide "de guata" qué clientes visitar y qué cargar en el furgón, y además hace casi todo lo demás en la empresa. En temporada baja no están llegando a la meta de +30 % de venta respecto al año anterior, y el combustible es su mayor costo.

**Lo que hicimos.** Una base de datos en 3FN que se alimenta con las ventas que se exportan del ERP Bicom. Cada domingo n8n corre los scripts que calculan qué clientes visitar, cuánto llevar de cada SKU sin pasarse de la capacidad del furgón y qué clientes están comprando menos, y le manda la hoja de ruta por correo al dueño.

---

## 1. Cómo correrlo (clonar, crear la base y ejecutar las consultas)

Solo se necesita el programa `sqlite3` (3.38 o más nuevo):
- Windows: bajar *sqlite-tools-win-x64* de <https://sqlite.org/download.html>, descomprimirlo y agregar la carpeta al PATH.
- macOS: viene instalado (se puede revisar con `sqlite3 --version`).
- Linux: `sudo apt install sqlite3`.

Los comandos se corren desde la carpeta principal del repo. Usamos `.read` en vez de `<` para que funcionen igual en CMD, PowerShell, macOS y Linux.

```bash
# 1) Clonar
git clone https://github.com/trinidad-usm/ICN292-Proyecto.git
cd ICN292-Proyecto
git checkout v1.0-e2

# 2) Crear y cargar la base (crea db/alimentos_emy.db)
sqlite3 db/alimentos_emy.db ".read db/schema.sql"
sqlite3 db/alimentos_emy.db ".read db/seed.sql"

# 3) Generar el plan semanal (lo que hace n8n cada domingo) y correr las consultas de negocio
sqlite3 db/alimentos_emy.db ".read db/procesos/generar_plan_semanal.sql"
sqlite3 db/alimentos_emy.db ".read db/consultas.sql"
```

En el paso 3 aparecen las tablas Q1 a Q7, que tienen que salir iguales a `db/resultados/resultados_consultas.txt`. Para compararlas sin revisar a ojo:

```bash
sqlite3 db/alimentos_emy.db ".read db/consultas.sql" > mi_salida.txt
# Linux/macOS:  diff mi_salida.txt db/resultados/resultados_consultas.txt
# Windows:      fc mi_salida.txt db\resultados\resultados_consultas.txt
```

`schema.sql` borra todo antes de crear las tablas, así que se puede repetir desde el paso 2 las veces que se quiera.

### 1.1 (Opcional) Probar la carga de una exportación nueva de Bicom

```bash
cp data/samples/export_bicom_ejemplo.csv data/entrada/export_bicom.csv     # Windows: copy
sqlite3 db/alimentos_emy.db ".read db/procesos/importar_ventas_bicom.sql"
sqlite3 db/alimentos_emy.db ".read db/procesos/generar_plan_semanal.sql"
```
Dejamos a propósito una línea con un SKU que no existe (`ZZ-999`) en el CSV de ejemplo, para que se vea que el script la rechaza y no la carga. Si se corre dos veces, los folios que ya estaban no se duplican.

### 1.2 (Opcional) Correr la automatización en n8n
Está explicado en [`docs/05-automatizacion-n8n.md`](docs/05-automatizacion-n8n.md). En resumen: importar `automatizacion/n8n_plan_semanal_emy.json`, cambiar la ruta del repo en los nodos *Configuración* y darle a *Ejecutar ahora (demo)*.

---

## 2. Qué hay en cada carpeta

```
ICN292-Proyecto/
├── README.md                     este archivo
├── CHANGELOG.md                  qué cambió desde la E1
├── ENLACE_GITHUB.txt             link del repo y tag de la versión que se defiende
├── docs/
│   ├── 00-caso-pyme.md           la empresa, el problema y qué queremos lograr
│   ├── 01-requerimientos.md      RF/RNF (MoSCoW) y dónde se cumple cada uno
│   ├── 02-bpmn.md                BPMN to-be final y cambios respecto a la E1
│   ├── 03-modelo-datos.md        ER en 3FN, diccionario de datos y anomalías que se evitan
│   ├── 04-sql-consultas.md       schema, seed y las consultas con sus resultados explicados
│   ├── 05-automatizacion-n8n.md  el flujo de n8n paso a paso y su relación con el BPMN
│   ├── DECLARACION_IA.md         declaración de uso de IA
│   └── img/                      diagramas (BPMN, ER) y capturas
├── db/
│   ├── schema.sql                tablas, PK/FK, CHECK, triggers, índices y vista
│   ├── seed.sql                  datos sintéticos (2025-01-01 a 2026-11-14)
│   ├── consultas.sql             las 7 consultas de negocio (Q1 a Q7)
│   ├── procesos/                 los scripts que corre n8n
│   │   ├── importar_ventas_bicom.sql   (RF1)
│   │   ├── generar_plan_semanal.sql    (RF2 a RF6, RF9)
│   │   ├── plan_json.sql               (RF7, el plan en JSON para el correo)
│   │   └── cumplimiento_json.sql       (RF8, reporte mensual en JSON)
│   └── resultados/               salidas guardadas para poder comparar
├── automatizacion/
│   ├── n8n_plan_semanal_emy.json flujo de n8n exportado (se puede importar)
│   └── evidencia/                lo que salió al correr el flujo en n8n
├── bpmn/                         to-be-final-e2.bpmn (se abre en bpmn.io), PNG y SVG
├── data/
│   ├── samples/                  exportación de Bicom de ejemplo (anonimizada)
│   └── entrada/                  carpeta donde n8n busca el CSV (los datos reales no se suben)
├── scripts/                      scripts en Python que generan el seed, el BPMN, el ER y el flujo n8n
├── informe/                      informe de la E2 en PDF y Word
└── presentacion/                 diapositivas de la defensa
```

### Cómo se conecta todo

```
Bicom (CSV) --> importar_ventas_bicom.sql --> BD en SQLite --> generar_plan_semanal.sql --> plan_json.sql --> correo al dueño
                  (n8n lo corre todos los domingos a las 19:00)

Día 1 de cada mes: n8n --> cumplimiento_json.sql --> correo con el cumplimiento de la meta
```
Cada tarea de servicio del BPMN to-be es un nodo de n8n, y cada nodo corre uno de los scripts SQL de esta carpeta. Las consultas Q1 a Q7 usan las mismas tablas, así que el proceso, los datos y los KPI calzan entre sí.

---

## 3. Sobre los datos

- Los datos de `seed.sql` son sintéticos y anonimizados (Ley 21.719). Ninguna fila es una venta real de la empresa. Los clientes aparecen como `CLI-###` y la ubicación solo por sector.
- Los armamos con los números que nos dio el dueño en la E1: 45 clientes, 3 rutas más una de fin de semana, un solo vehículo, temporada baja de marzo a agosto, y la meta de +30 % cumplida de enero a mayo pero no de junio a agosto de 2026. Septiembre y octubre de 2026 son supuestos nuestros.
- `seed.sql` se puede volver a generar con `python3 scripts/generar_seed.py`. Usa una semilla fija, así que sale exactamente igual en cualquier computador, y no necesita instalar librerías.
- Todos los números del informe y de la presentación salen de `db/resultados/resultados_consultas.txt`, y se pueden reproducir con los comandos de la sección 1.

## 4. Volver a generar archivos (opcional)

| Archivo | Comando |
|---|---|
| `db/seed.sql` | `python3 scripts/generar_seed.py` |
| `automatizacion/n8n_plan_semanal_emy.json` | `python3 scripts/construir_workflow_n8n.py` |
| `bpmn/to-be-final-e2.bpmn` | `python3 scripts/construir_bpmn.py` (se abre en <https://demo.bpmn.io>) |
| `docs/img/er-3fn.png` | `python3 scripts/er.py` (necesita Graphviz y la base ya creada) |
