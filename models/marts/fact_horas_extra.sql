{{
    config(
        materialized='incremental',
        unique_key='horas_extra_key',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

-- ════════════════════════════════════════════════════════════════════════════
-- Fact: horas extra realizadas por empleados
-- ────────────────────────────────────────────────────────────────────────────
-- Granularidad: una fila por hora extra (PK natural = id_hora_extra).
-- Carga: incremental con MERGE + lookback de 7 días.
-- SCD: empleado_key resuelta point-in-time contra dim_empleado SCD2.
-- ════════════════════════════════════════════════════════════════════════════

WITH

stg_extra_hours AS (
    SELECT * FROM {{ ref('stg_bronze__extra_hours') }}
    {% if is_incremental() %}
        -- ────────────────────────────────────────────────────────────
        -- Lookback window de reprocesamiento
        -- ────────────────────────────────────────────────────────────
        -- Un filtro estricto "> MAX(fecha_actualizacion)" perdería registros 
        -- modificados retroactivamente en MariaDB 
        --
        -- El MERGE aplica UPDATE sobre filas existentes y INSERT sobre nuevas,
        -- garantizando idempotencia.
        --
        -- 7 días es seguro para el dominio. Configurable vía dbt vars.
        -- ────────────────────────────────────────────────────────────
        WHERE fecha_actualizacion >= DATEADD(
            day,
            -{{ var('reprocess_days', 7) }},
            (SELECT MAX(fecha_actualizacion) FROM {{ this }})
        )
    {% endif %}
),

stg_salaries AS (
    SELECT * FROM {{ ref('stg_bronze__salaries') }}
),

stg_guards AS (
    SELECT * FROM {{ ref('stg_bronze__guards') }}
),

-- Deduplicación de guardias por fecha vía QUALIFY (sintaxis nativa de Snowflake
-- para filtrar sobre window functions, equivalente a CTE + WHERE rn=1 pero más legible).
guards_unique AS (
    SELECT
        fecha,
        tipo_dia,
        id_brigada,
        id_parque
    FROM stg_guards
    QUALIFY ROW_NUMBER() OVER (PARTITION BY fecha ORDER BY id_guardia) = 1
),

-- Enriquecimiento: une horas extra con salario aplicable y contexto de guardia.
-- Cálculo de medidas monetarias en este paso para que el modelo final sea solo SELECT.
horas_extra_enriched AS (
    SELECT
        eh.id_hora_extra,
        eh.fecha,
        eh.id_empleado,
        eh.id_salario,
        eh.horas_diurnas,
        eh.horas_nocturnas,
        eh.total_horas,
        s.tipo_salario,
        s.precio_hora_diurna,
        s.precio_hora_nocturna,
        g.tipo_dia,
        COALESCE(g.id_brigada, -1) AS id_brigada_guardia,
        g.id_parque AS id_parque_guardia,
        eh.horas_diurnas * s.precio_hora_diurna AS coste_diurno,
        eh.horas_nocturnas * s.precio_hora_nocturna AS coste_nocturno,
        (eh.horas_diurnas * s.precio_hora_diurna)
            + (eh.horas_nocturnas * s.precio_hora_nocturna) AS coste_total,
        eh.fecha_creacion,
        eh.fecha_actualizacion
    FROM stg_extra_hours eh
    LEFT JOIN stg_salaries s
        ON eh.id_salario = s.id_salario
    LEFT JOIN guards_unique g
        ON eh.fecha = g.fecha
),

-- Point-in-time lookup contra dim_empleado SCD2.
-- Asocia cada hora extra con la versión del empleado vigente en `fecha`,
-- no con la versión actual. Garantiza trazabilidad histórica: si un empleado
-- cambió de puesto en marzo, las horas extra de febrero apuntan al puesto antiguo.
horas_extra_with_empleado AS (
    SELECT
        h.*,
        {{ lookup_empleado_scd2('h.id_empleado', 'h.fecha') }} AS empleado_key
    FROM horas_extra_enriched h
    LEFT JOIN {{ ref('dim_empleado') }} de
        {{ join_empleado_scd2('h.id_empleado', 'h.fecha') }}
),

final AS (
    SELECT
        -- ── Surrogate keys (Kimball) ──────────────────────────────────────
        {{ dbt_utils.generate_surrogate_key(['id_hora_extra']) }} AS horas_extra_key,
        empleado_key,                                                    -- versionada SCD2
        {{ dbt_utils.generate_surrogate_key(['fecha']) }} AS fecha_key,
        
        CASE
            WHEN id_brigada_guardia = -1 THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['id_brigada_guardia']) }}
        END AS brigada_key,

        CASE
            WHEN id_salario IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['id_salario']) }}
        END AS salario_key,

        -- ── Degenerate dimensions y business keys ─────────────────────────
        -- Mantenidas junto a las surrogate keys para facilitar debugging
        -- y exploración ad-hoc del fact sin necesidad de joins.
        id_hora_extra,
        id_empleado,
        fecha,
        id_salario,

        -- ── Medidas aditivas ──────────────────────────────────────────────
        horas_diurnas,
        horas_nocturnas,
        total_horas,
        precio_hora_diurna,
        precio_hora_nocturna,
        coste_diurno,
        coste_nocturno,
        coste_total,

        -- ── Contexto descriptivo ──────────────────────────────────────────
        tipo_dia,
        tipo_salario,

        -- ── Auditoría ─────────────────────────────────────────────────────
        fecha_creacion,
        fecha_actualizacion
    FROM horas_extra_with_empleado
)

SELECT * FROM final