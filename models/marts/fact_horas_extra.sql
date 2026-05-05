
{{
    config(
        materialized='incremental',
        unique_key='horas_extra_key',
        on_schema_change='append_new_columns'
    )
}}

WITH 

stg_extra_hours AS (
    SELECT * FROM {{ ref('stg_bronze__extra_hours') }}
    {% if is_incremental() %}
        WHERE fecha_actualizacion > (SELECT MAX(fecha_actualizacion) FROM {{ this }})
    {% endif %}
),

stg_salaries AS (
    SELECT * FROM {{ ref('stg_bronze__salaries') }}
),

stg_guards AS (
    SELECT * FROM {{ ref('stg_bronze__guards') }}
),

guards_per_date AS (
    SELECT
        fecha
        , tipo_dia
        , id_brigada
        , id_parque
        , ROW_NUMBER() OVER (PARTITION BY fecha ORDER BY id_guardia) AS rn
    FROM stg_guards
),

guards_unique AS (
    SELECT fecha, tipo_dia, id_brigada, id_parque
    FROM guards_per_date
    WHERE rn = 1
),

horas_extra_enriched AS (
    SELECT
        eh.id_hora_extra
        , eh.fecha
        , eh.id_empleado
        , eh.id_salario
        , eh.horas_diurnas
        , eh.horas_nocturnas
        , eh.total_horas
        , s.tipo_salario
        , s.precio_hora_diurna
        , s.precio_hora_nocturna
        , g.tipo_dia
        , COALESCE(g.id_brigada, -1) AS id_brigada_guardia
        , g.id_parque AS id_parque_guardia
        , eh.horas_diurnas * s.precio_hora_diurna AS coste_diurno
        , eh.horas_nocturnas * s.precio_hora_nocturna AS coste_nocturno
        , (eh.horas_diurnas * s.precio_hora_diurna) 
          + (eh.horas_nocturnas * s.precio_hora_nocturna) AS coste_total
        , eh.fecha_creacion
        , eh.fecha_actualizacion
    FROM stg_extra_hours eh
    LEFT JOIN stg_salaries s
        ON eh.id_salario = s.id_salario
    LEFT JOIN guards_unique g
        ON eh.fecha = g.fecha
),

-- point-in-time lookup contra dim_empleado SCD2
horas_extra_with_empleado AS (
    SELECT
        h.*
        , {{ lookup_empleado_scd2('h.id_empleado', 'h.fecha') }} AS empleado_key
    FROM horas_extra_enriched h
    LEFT JOIN {{ ref('dim_empleado') }} de
        {{ join_empleado_scd2('h.id_empleado', 'h.fecha') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_hora_extra']) }} AS horas_extra_key
        , empleado_key                                                           -- ← versionada SCD2
        , {{ dbt_utils.generate_surrogate_key(['fecha']) }} AS fecha_key
        , {{ dbt_utils.generate_surrogate_key(['id_brigada_guardia']) }} AS brigada_key
        , {{ dbt_utils.generate_surrogate_key(['id_salario']) }} AS salario_key
        -- degenerate dimensions
        , id_hora_extra
        , id_empleado
        , fecha
        , id_salario
        -- medidas
        , horas_diurnas
        , horas_nocturnas
        , total_horas
        , precio_hora_diurna
        , precio_hora_nocturna
        , coste_diurno
        , coste_nocturno
        , coste_total
        -- contexto
        , tipo_dia
        , tipo_salario
        -- auditoría
        , fecha_creacion
        , fecha_actualizacion
    FROM horas_extra_with_empleado
)

SELECT * FROM final