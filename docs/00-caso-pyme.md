# 00. Caso PYME: Alimentos Emy

Es la misma PYME de la Entrega 1. La información viene de la reunión que tuvimos con el dueño el 26 de agosto de 2026 y del formulario que él respondió (informe E1, sección B).

## Identificación

| Campo | Valor |
|---|---|
| Nombre de fantasía | Alimentos Emy |
| Razón social | Comercializadora de Alimentos Eduardo Santibáñez Acuña EIRL |
| Giro | Venta al por mayor de huevos, lácteos, abarrotes y otros alimentos; distribuidor de Quillayes/Surlat y Colun |
| Canal | Tradicional (minimarkets, almacenes de barrio) bajo modalidad de autoventa: venta, facturación y despacho en la misma visita |
| Ubicación | Bodega en Olivar (Región de O'Higgins); atiende Rancagua, Machalí, Doñihue y Olivar |
| Tamaño | EIRL, 2 colaboradores fijos + 1 de apoyo; el dueño es vendedor, chofer, bodeguero, facturador y administrador |
| Cartera | 45 clientes activos, 3 rutas semanales fijas + ruta de fin de semana, un vehículo |
| Sistemas actuales | ERP/app Bicom (facturación en terreno, stock), WhatsApp con clientes, *planner* de papel |

## Problema (medible)

Alimentos Emy no tiene un proceso definido para planificar las rutas ni para decidir qué cargar para cada cliente y zona usando su historial de ventas. Según el dueño, esto le trae estos problemas:

1. Meta comercial incumplida en temporada baja. Meta interna: +30 % de venta vs. el mismo mes del año anterior. Se cumplió enero-mayo 2026 (con caída en marzo) y no en junio, julio y agosto 2026.
2. Sobrecosto de combustible, su principal partida de costo operativo, por recorridos y cargas no optimizados.
3. Quiebres de stock en el camión: no se anticipa qué familias demanda cada zona; el nivel de servicio (*fill rate*) no se mide.
4. Escalabilidad nula: la planificación es "de guata" y no se puede delegar a un tercero.

## Objetivo del SIG

Usar el historial de ventas que ya está en Bicom para automatizar la planificación de la semana (a quién visitar, en qué orden y qué cargar sin pasarse de la capacidad del furgón). También queremos medir cosas que hoy no se miden, como el cumplimiento de la meta, el *fill rate* y la efectividad de las visitas, y avisar cuando un cliente empieza a comprar menos. La idea de fondo es que el dueño pueda delegar la ruta.

## KPIs que el SIG entrega (y dónde se calculan)

| KPI | Definición | Consulta |
|---|---|---|
| Cumplimiento de meta | venta mes / (venta mismo mes año anterior × 1,30) | Q1 + flujo n8n mensual |
| Nivel de servicio (*fill rate*) | unidades despachadas / unidades solicitadas | Q2 |
| Uso de capacidad del furgón | kg planificados / capacidad kg | Q3b |
| Efectividad de visita | visitas con venta / visitas | Q6 |
| Clientes en riesgo | compras/semana reciente < 60 % de su patrón histórico | Q5 |

## Datos y privacidad (Ley 21.719)

Como el profesor revisa el repositorio, aquí no hay datos reales de la empresa ni de sus clientes. Usamos datos sintéticos y anonimizados que respetan los números que nos dio el dueño (ver `README.md`, sección 3). Los datos reales de Bicom van en `data/entrada/`, que está en el `.gitignore` y por eso no se sube.
