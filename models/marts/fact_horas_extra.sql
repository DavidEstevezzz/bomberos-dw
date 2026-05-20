{{
    config(
        materialized='incremental',
        unique_key='horas_extra_key',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

WITH

stg_extra_hours AS (
    SELECT * FROM {{ ref('stg_bronze__extra_hours') }}

    {% if is_incremental() %}
        WHERE fecha_actualizacion >= DATEADD(
            day,
            -{{ var('reprocess_days', 7) }},
            (
                SELECT COALESCE(MAX(fecha_actualizacion), '1900-01-01'::timestamp_ntz)
                FROM {{ this }}
            )
        )
    {% endif %}
),

stg_salaries AS (
    SELECT * FROM {{ ref('stg_bronze__salaries') }}
),

stg_guards AS (
    SELECT * FROM {{ ref('stg_bronze__guards') }}
),

stg_brigades AS (
    SELECT * FROM {{ ref('stg_bronze__brigades') }}
),

-- Colapsamos Norte/Sur por nombre de brigada.
-- Si en una fecha existen Brigada A Norte y Brigada A Sur,
-- nos quedamos con una sola Brigada A para no duplicar horas extra.
guards_collapsed_by_brigade AS (
    SELECT
        g.fecha
        , b.nombre_brigada
        , MIN(g.tipo_dia) AS tipo_dia
        , MIN(g.id_brigada) AS id_brigada_guardia
    FROM stg_guards g
    LEFT JOIN stg_brigades b
        ON g.id_brigada = b.id_brigada
    WHERE b.nombre_brigada IN (
        'Brigada A',
        'Brigada B',
        'Brigada C',
        'Brigada D',
        'Brigada E',
        'Brigada F'
    )
    GROUP BY
        g.fecha
        , b.nombre_brigada
),

-- En condiciones normales debe quedar una única brigada operativa por fecha.
-- Si hubiera más de una, se elige una de forma determinista por nombre.
guards_unique AS (
    SELECT
        fecha
        , tipo_dia
        , id_brigada_guardia
    FROM guards_collapsed_by_brigade
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY fecha
        ORDER BY nombre_brigada
    ) = 1
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
        , COALESCE(g.id_brigada_guardia, -1) AS id_brigada_guardia

        , eh.horas_diurnas * s.precio_hora_diurna AS coste_diurno
        , eh.horas_nocturnas * s.precio_hora_nocturna AS coste_nocturno
        , (eh.horas_diurnas * s.precio_hora_diurna)
            + (eh.horas_nocturnas * s.precio_hora_nocturna) AS coste_total

        , eh.fecha_creacion
        , eh.fecha_actualizacion
        , eh.fecha_carga_bronze

    FROM stg_extra_hours eh
    LEFT JOIN stg_salaries s
        ON eh.id_salario = s.id_salario
    LEFT JOIN guards_unique g
        ON eh.fecha = g.fecha
),

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
        , empleado_key
        , {{ dbt_utils.generate_surrogate_key(['fecha']) }} AS fecha_key

        , CASE
            WHEN id_brigada_guardia = -1 THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['id_brigada_guardia']) }}
          END AS brigada_key

        , CASE
            WHEN id_salario IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['id_salario']) }}
          END AS salario_key

        , id_hora_extra
        , id_empleado
        , fecha
        , id_salario

        , horas_diurnas
        , horas_nocturnas
        , total_horas
        , precio_hora_diurna
        , precio_hora_nocturna
        , coste_diurno
        , coste_nocturno
        , coste_total

        , tipo_dia
        , tipo_salario

        , fecha_creacion
        , fecha_actualizacion
        , fecha_carga_bronze

    FROM horas_extra_with_empleado
)

SELECT * FROM final