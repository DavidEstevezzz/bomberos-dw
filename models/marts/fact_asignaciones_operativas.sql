{{
    config(
        materialized='incremental',
        unique_key='asignacion_key',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

WITH

stg_assignments AS (
    SELECT *
    FROM {{ ref('stg_bronze__firefighters_assignments') }}

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

-- Point-in-time lookup contra dim_empleado SCD2
assignments_with_empleado AS (
    SELECT
        a.*
        , {{ lookup_empleado_scd2('a.id_empleado', 'a.fecha_inicio') }} AS empleado_key
    FROM stg_assignments a
    LEFT JOIN {{ ref('dim_empleado') }} de
        {{ join_empleado_scd2('a.id_empleado', 'a.fecha_inicio') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_asignacion']) }} AS asignacion_key

        , empleado_key

        , {{ dbt_utils.generate_surrogate_key(['fecha_inicio']) }} AS fecha_key

        , CASE
            WHEN id_brigada_origen IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['id_brigada_origen']) }}
            ELSE NULL
          END AS brigada_origen_key

        , CASE
            WHEN id_brigada_destino IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['id_brigada_destino']) }}
            ELSE NULL
          END AS brigada_destino_key

        , CASE
            WHEN id_solicitud IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['id_solicitud']) }}
            ELSE NULL
          END AS solicitud_key

        , CASE
            WHEN id_cambio_guardia IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['id_cambio_guardia']) }}
            ELSE NULL
          END AS cambio_guardia_key

        -- claves naturales / degenerate dimensions
        , id_asignacion
        , id_empleado
        , id_brigada_origen
        , id_brigada_destino
        , id_solicitud
        , id_cambio_guardia
        , id_traslado

        -- atributos
        , fecha_inicio
        , turno
        , tipo_asignacion
        , es_requerimiento

        -- medidas binarias
        , 1 AS total_asignaciones
        , CASE WHEN es_requerimiento THEN 1 ELSE 0 END AS total_requerimientos
        , CASE WHEN tipo_asignacion = 'ida' THEN 1 ELSE 0 END AS total_idas
        , CASE WHEN tipo_asignacion = 'vuelta' THEN 1 ELSE 0 END AS total_vueltas

        -- auditoría
        , fecha_creacion
        , fecha_actualizacion

    FROM assignments_with_empleado
)

SELECT * FROM final