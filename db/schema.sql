-- schema.sql - Alimentos Emy (ICN-292, E2)
-- Crea las tablas del modelo en 3FN con sus PK, FK, restricciones, triggers, índices
-- y la vista v_linea_venta. Motor: SQLite 3.38 o más nuevo.
-- Primero borra todo lo que exista, así que se puede correr las veces que haga falta.
-- Uso (desde la carpeta del repo): sqlite3 db/alimentos_emy.db ".read db/schema.sql"
-- El diccionario de datos y la explicación de la 3FN están en docs/03-modelo-datos.md

PRAGMA foreign_keys = ON;

DROP VIEW    IF EXISTS v_linea_venta;
DROP TRIGGER IF EXISTS trg_venta_requiere_resultado_venta;
DROP TRIGGER IF EXISTS trg_visita_posterior_alta;
DROP TABLE   IF EXISTS stg_venta_bicom;
DROP TABLE   IF EXISTS alerta_cliente;
DROP TABLE   IF EXISTS plan_visita;
DROP TABLE   IF EXISTS plan_carga_detalle;
DROP TABLE   IF EXISTS plan_carga;
DROP TABLE   IF EXISTS detalle_venta;
DROP TABLE   IF EXISTS venta;
DROP TABLE   IF EXISTS visita;
DROP TABLE   IF EXISTS ruta_cliente;
DROP TABLE   IF EXISTS ruta;
DROP TABLE   IF EXISTS vehiculo;
DROP TABLE   IF EXISTS producto;
DROP TABLE   IF EXISTS familia_producto;
DROP TABLE   IF EXISTS cliente;
DROP TABLE   IF EXISTS zona;
DROP TABLE   IF EXISTS parametro;

CREATE TABLE parametro (
    clave        TEXT PRIMARY KEY,
    valor        REAL NOT NULL,
    descripcion  TEXT NOT NULL
);

CREATE TABLE zona (
    id_zona  TEXT PRIMARY KEY,   -- ej. 'Z01'
    nombre   TEXT NOT NULL UNIQUE,   -- sector (cuadrante)
    comuna   TEXT NOT NULL
);

CREATE TABLE cliente (
    id_cliente        TEXT PRIMARY KEY
                      CHECK (id_cliente GLOB 'CLI-[0-9][0-9][0-9]'), -- código en vez del nombre real (Ley 21.719)
    nombre_fantasia   TEXT NOT NULL,  -- también anonimizado
    tipo_negocio      TEXT NOT NULL
                      CHECK (tipo_negocio IN ('MINIMARKET','ALMACEN','BOTILLERIA','PANADERIA')),
    id_zona           TEXT NOT NULL REFERENCES zona(id_zona),
    frecuencia_visita TEXT NOT NULL
                      CHECK (frecuencia_visita IN ('SEMANAL','QUINCENAL','MENSUAL')),
    fecha_alta        DATE NOT NULL,
    activo            INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1))
);

CREATE TABLE familia_producto (
    id_familia    TEXT PRIMARY KEY,  -- ej. 'LEC'
    nombre        TEXT NOT NULL UNIQUE,
    requiere_frio INTEGER NOT NULL CHECK (requiere_frio IN (0,1))
);

CREATE TABLE producto (
    sku           TEXT PRIMARY KEY,  -- mismo código que usa Bicom
    nombre        TEXT NOT NULL,
    marca         TEXT NOT NULL,
    id_familia    TEXT NOT NULL REFERENCES familia_producto(id_familia),
    peso_kg       REAL NOT NULL CHECK (peso_kg > 0), -- kg por unidad
    precio_lista  INTEGER NOT NULL CHECK (precio_lista > 0), -- precio actual, neto en CLP
    activo        INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1))
);

CREATE TABLE vehiculo (
    id_vehiculo   TEXT PRIMARY KEY,
    descripcion   TEXT NOT NULL,
    capacidad_kg  REAL NOT NULL CHECK (capacidad_kg > 0) -- RF6
);

CREATE TABLE ruta (
    id_ruta       TEXT PRIMARY KEY,  -- ej. 'R-LUN'
    nombre        TEXT NOT NULL UNIQUE,
    dia_semana    INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1 = lunes
    id_zona       TEXT NOT NULL REFERENCES zona(id_zona),
    id_vehiculo   TEXT NOT NULL REFERENCES vehiculo(id_vehiculo)
);

CREATE TABLE ruta_cliente (
    id_ruta       TEXT NOT NULL REFERENCES ruta(id_ruta),
    id_cliente    TEXT NOT NULL REFERENCES cliente(id_cliente),
    orden_visita  INTEGER NOT NULL CHECK (orden_visita > 0),
    PRIMARY KEY (id_ruta, id_cliente),
    UNIQUE (id_ruta, orden_visita)
);

CREATE TABLE visita (
    id_visita     INTEGER PRIMARY KEY,
    id_ruta       TEXT NOT NULL,
    id_cliente    TEXT NOT NULL,
    fecha         DATE NOT NULL CHECK (fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    resultado     TEXT NOT NULL
                  CHECK (resultado IN ('VENTA','AUSENTE','SIN_SALDO','SIN_REPOSICION')),
    UNIQUE (id_cliente, fecha),
    -- el cliente tiene que estar asignado a esa ruta
    FOREIGN KEY (id_ruta, id_cliente) REFERENCES ruta_cliente(id_ruta, id_cliente)
);

CREATE TABLE venta (
    id_venta       INTEGER PRIMARY KEY,
    id_visita      INTEGER NOT NULL UNIQUE REFERENCES visita(id_visita), -- una visita tiene como máximo una venta
    folio_bicom    TEXT NOT NULL UNIQUE,  -- folio de la boleta/factura en Bicom
    tipo_documento TEXT NOT NULL CHECK (tipo_documento IN ('BOLETA','FACTURA')),
    medio_pago     TEXT NOT NULL CHECK (medio_pago IN ('EFECTIVO','TRANSFERENCIA','TARJETA'))
);

CREATE TABLE detalle_venta (
    id_venta            INTEGER NOT NULL REFERENCES venta(id_venta) ON DELETE CASCADE,
    sku                 TEXT    NOT NULL REFERENCES producto(sku),
    cantidad_solicitada INTEGER NOT NULL CHECK (cantidad_solicitada > 0),
    cantidad_despachada INTEGER NOT NULL
                        CHECK (cantidad_despachada >= 0 AND cantidad_despachada <= cantidad_solicitada),
    precio_unitario     INTEGER NOT NULL CHECK (precio_unitario > 0), -- precio cobrado ese día (puede ser distinto al de lista)
    PRIMARY KEY (id_venta, sku)
);

CREATE TABLE plan_carga (
    id_plan           INTEGER PRIMARY KEY,
    id_ruta           TEXT NOT NULL REFERENCES ruta(id_ruta),
    fecha_ruta        DATE NOT NULL,
    fecha_generacion  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    estado            TEXT NOT NULL DEFAULT 'SUGERIDO'
                      CHECK (estado IN ('SUGERIDO','APROBADO','EJECUTADO')),
    UNIQUE (id_ruta, fecha_ruta)
);

CREATE TABLE plan_carga_detalle (
    id_plan             INTEGER NOT NULL REFERENCES plan_carga(id_plan) ON DELETE CASCADE,
    sku                 TEXT    NOT NULL REFERENCES producto(sku),
    unidades_sugeridas  INTEGER NOT NULL CHECK (unidades_sugeridas >= 0),
    PRIMARY KEY (id_plan, sku)
);

CREATE TABLE plan_visita (
    id_plan     INTEGER NOT NULL REFERENCES plan_carga(id_plan) ON DELETE CASCADE,
    id_cliente  TEXT    NOT NULL REFERENCES cliente(id_cliente),
    PRIMARY KEY (id_plan, id_cliente)
);

CREATE TABLE alerta_cliente (
    id_alerta              INTEGER PRIMARY KEY,
    id_cliente             TEXT NOT NULL REFERENCES cliente(id_cliente),
    fecha_alerta           DATE NOT NULL,
    compras_sem_historico  REAL NOT NULL CHECK (compras_sem_historico >= 0), -- valores al momento de crear la alerta
    compras_sem_reciente   REAL NOT NULL CHECK (compras_sem_reciente  >= 0),
    estado                 TEXT NOT NULL DEFAULT 'ABIERTA'
                           CHECK (estado IN ('ABIERTA','GESTIONADA','CERRADA')),
    UNIQUE (id_cliente, fecha_alerta)
);

CREATE TABLE stg_venta_bicom (
    folio          TEXT,
    fecha          TEXT,
    id_cliente     TEXT,
    sku            TEXT,
    cantidad       INTEGER,
    precio_unitario INTEGER,
    tipo_documento TEXT,
    medio_pago     TEXT
);

CREATE TRIGGER trg_venta_requiere_resultado_venta
BEFORE INSERT ON venta
WHEN (SELECT resultado FROM visita WHERE id_visita = NEW.id_visita) <> 'VENTA'
BEGIN
    SELECT RAISE(ABORT, 'R1: la visita asociada no tiene resultado VENTA');
END;

CREATE TRIGGER trg_visita_posterior_alta
BEFORE INSERT ON visita
WHEN NEW.fecha < (SELECT fecha_alta FROM cliente WHERE id_cliente = NEW.id_cliente)
BEGIN
    SELECT RAISE(ABORT, 'R2: visita anterior a la fecha de alta del cliente');
END;

CREATE INDEX ix_visita_fecha        ON visita(fecha);

CREATE INDEX ix_visita_cliente      ON visita(id_cliente);

CREATE INDEX ix_cliente_zona        ON cliente(id_zona);

CREATE INDEX ix_producto_familia    ON producto(id_familia);

CREATE INDEX ix_detalle_sku         ON detalle_venta(sku);

CREATE VIEW v_linea_venta AS
SELECT  vi.fecha,
        strftime('%Y', vi.fecha)              AS anio,
        CAST(strftime('%m', vi.fecha) AS INTEGER) AS mes,
        vi.id_ruta,
        c.id_cliente,
        c.id_zona,
        p.id_familia,
        d.sku,
        d.cantidad_solicitada,
        d.cantidad_despachada,
        d.precio_unitario,
        d.cantidad_despachada * d.precio_unitario AS monto_neto,
        d.cantidad_despachada * p.peso_kg         AS kg_despachados
FROM detalle_venta d
JOIN venta    v  ON v.id_venta   = d.id_venta
JOIN visita   vi ON vi.id_visita = v.id_visita
JOIN cliente  c  ON c.id_cliente = vi.id_cliente
JOIN producto p  ON p.sku        = d.sku;

