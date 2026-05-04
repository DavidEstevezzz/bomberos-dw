{{
    config(
        materialized='incremental',
        unique_key='incidencia_key',
        on_schema_change='append_new_columns'
    )
}}

WITH 

-- import CTEs
stg_incidents AS (
    SELECT * FROM {{ ref('stg_bronze__incidents') }}
    {% if is_incremental() %}
        WHERE fecha_actualizacion > (SELECT MAX(fecha_actualizacion) FROM {{ this }})
    {% endif %}
),

-- surrogate keys + métricas
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_incidencia']) }} AS incidencia_key
        , {{ dbt_utils.generate_surrogate_key(['id_empleado_creador']) }} AS empleado_creador_key
        , {{ dbt_utils.generate_surrogate_key(['id_empleado_resolutor']) }} AS empleado_resolutor_key
        , {{ dbt_utils.generate_surrogate_key(['fecha_incidencia']) }} AS fecha_key
        , {{ dbt_utils.generate_surrogate_key(['id_parque']) }} AS parque_key
        , {{ dbt_utils.generate_surrogate_key(['matricula_vehiculo']) }} AS vehiculo_key
        , {{ dbt_utils.generate_surrogate_key(['id_equipo']) }} AS equipo_key
        -- degenerate dimensions
        , id_incidencia
        , id_empleado_creador
        , id_empleado_resolutor
        , id_empleado_referenciado
        , fecha_incidencia
        , id_parque
        , matricula_vehiculo
        , id_equipo
        , nombre_equipo_comun
        -- atributos del hecho
        , tipo_incidencia
        , estado
        , nivel_gravedad
        , esta_leido
        -- medidas
        , dias_resolucion
        , CASE
            WHEN estado = 'resuelta' THEN 1
            ELSE 0
          END AS es_resuelta
        , CASE
            WHEN estado = 'pendiente' THEN 1
            ELSE 0
          END AS es_pendiente
        , CASE
            WHEN estado = 'tramitada' THEN 1
            ELSE 0
          END AS es_tramitada
        -- auditoría
        , fecha_creacion
        , fecha_actualizacion
    FROM stg_incidents
)

SELECT * FROM final