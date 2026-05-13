# Bomberos DW

Proyecto de **Data Warehouse analítico** construido con **dbt** y **Snowflake** a partir de datos operativos del sistema de gestión de Bomberos de Granada.

El objetivo principal es transformar datos transaccionales procedentes de un sistema OLTP en un modelo analítico preparado para estudiar costes, permisos, presión operativa, asignaciones e incidencias.

## Objetivo del proyecto

Este proyecto busca demostrar un flujo completo de analytics engineering:

- Ingesta de datos brutos en una capa Bronze.
- Limpieza y normalización en una capa Silver/Staging.
- Construcción de un modelo dimensional en Gold.
- Creación de modelos analíticos orientados a casos de uso concretos.
- Aplicación de tests de calidad, documentación y buenas prácticas profesionales de dbt.

## Arquitectura

El proyecto sigue una arquitectura por capas:

Bronze → Silver / Staging → Gold / Marts → Analytics

### Bronze

Contiene datos brutos extraídos desde el sistema operacional original.

La PII sensible se encuentra anonimizada o tokenizada, por ejemplo nombres de empleados y matrículas de vehículos.

### Silver / Staging

Capa de limpieza y estandarización.

Aquí se realizan tareas como:

- Renombrado semántico de columnas.
- Casteo de tipos.
- Normalización de estados y categorías.
- Cálculo de campos derivados.
- Filtrado defensivo de datos corruptos.
- Tests básicos de calidad.

### Gold / Marts

Capa dimensional orientada al análisis.

Incluye dimensiones y tablas de hechos para analizar procesos de negocio como:

- Horas extra.
- Solicitudes y permisos.
- Asignaciones operativas.
- Incidencias.
- Empleados, brigadas, parques, vehículos y equipos.

### Analytics

Capa final con modelos agregados para responder preguntas de negocio sobre costes, presión operativa, estacionalidad, gestión de permisos e incidencias.

## Principales skills implementadas

Este proyecto incluye prácticas habituales en entornos profesionales de datos:

- Modelado medallion: Bronze, Silver, Gold y Analytics.
- Modelado dimensional tipo Kimball.
- Dimensiones y tablas de hechos.
- Surrogate keys con `dbt_utils`.
- Dimensión de empleado con histórico SCD Tipo 2.
- Snapshots de dbt.
- Modelos incrementales con estrategia `merge`.
- Ventana de reprocesamiento para capturar cambios retroactivos.
- Tests de calidad de datos:
  - `not_null`;
  - `unique`;
  - `relationships`;
  - `accepted_values`;
  - reglas de negocio con `dbt_utils.expression_is_true`;
  - singular tests SQL;
  - unit tests de dbt.
- Contratos de modelos en Gold.
- Uso de `tags`, `meta`, `groups` y `access`.
- Documentación técnica de modelos y columnas.
- Query comments para trazabilidad en Snowflake.
- Anonimización/tokenización de datos sensibles.

## Casos de uso analíticos

### Coste de horas extra

Permite analizar el coste de horas extra por empleado, fecha, tipo de día, tarifa salarial, brigada o parque.

### Presión operativa

Permite estudiar cómo las solicitudes, permisos, cambios de guardia y requerimientos afectan a la operativa diaria.

### Incidencias

Permite analizar incidencias sobre vehículos, equipos, personal e instalaciones, incluyendo estado, gravedad y tiempo de resolución.

## Estructura del proyecto

```text
.
├── analyses/              # Consultas analíticas auxiliares
├── macros/                # Macros reutilizables
├── models/
│   ├── staging/           # Modelos Silver sobre fuentes Bronze
│   └── marts/             # Dimensiones, hechos y modelos analytics
├── seeds/                 # Datos semilla
├── snapshots/             # Snapshots SCD2
├── tests/                 # Singular tests SQL
├── dbt_project.yml        # Configuración principal de dbt
└── packages.yml           # Dependencias del proyecto
```

## Ejecución básica

Instalar dependencias:

```bash
dbt deps
```

Comprobar configuración:

```bash
dbt debug
```

Ejecutar modelos:

```bash
dbt run
```

Ejecutar tests:

```bash
dbt test
```

Ejecutar build completo:

```bash
dbt build
```

## Estado del proyecto

Proyecto demostrativo orientado a mostrar buenas prácticas de **Data Engineering** con dbt y Snowflake.
