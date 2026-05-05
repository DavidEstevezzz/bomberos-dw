
{{
    config(
        materialized='incremental',
        unique_key='incidencia_key',
        on_schema_change='append_new_columns'
    )
}}

WITH 

stg_incidents AS (
    SELECT * FROM {{ ref('stg_bronze__incidents') }}
    {% if is_incremental() %}
        WHERE fecha_actualizacion > (SELECT MAX(fecha_actualizacion) FROM {{ this }})
    {% endif %}
),

-- fecha de efecto del resolutor: solo cuando hay resolución real
incidents_with_resolution_date AS (
    SELECT
        i.*
        , CASE
            WHEN i.estado = 'resuelta' AND i.id_empleado_resolutor IS NOT NULL
            THEN i.fecha_actualizacion
            ELSE NULL
          END AS fecha_efecto_resolutor
    FROM stg_incidents i
),

-- point-in-time lookup: empleado creador con fecha_incidencia
incidents_with_creator AS (
    SELECT
        i.*
        , {{ lookup_empleado_scd2('i.id_empleado_creador', 'i.fecha_incidencia', alias='dec') }} AS empleado_creador_key
    FROM incidents_with_resolution_date i
    LEFT JOIN {{ ref('dim_empleado') }} dec
        {{ join_empleado_scd2('i.id_empleado_creador', 'i.fecha_incidencia', alias='dec') }}
),

-- point-in-time lookup: empleado resolutor con fecha_actualizacion (solo si resuelta)
incidents_with_resolver AS (
    SELECT
        i.*
        , {{ lookup_empleado_scd2('i.id_empleado_resolutor', 'i.fecha_efecto_resolutor', alias='der') }} AS empleado_resolutor_key
    FROM incidents_with_creator i
    LEFT JOIN {{ ref('dim_empleado') }} der
        {{ join_empleado_scd2('i.id_empleado_resolutor', 'i.fecha_efecto_resolutor', alias='der') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_incidencia']) }} AS incidencia_key
        , empleado_creador_key
        , empleado_resolutor_key
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
        , CASE WHEN estado = 'resuelta' THEN 1 ELSE 0 END AS es_resuelta
        , CASE WHEN estado = 'pendiente' THEN 1 ELSE 0 END AS es_pendiente
        , CASE WHEN estado = 'tramitada' THEN 1 ELSE 0 END AS es_tramitada
        -- auditoría
        , fecha_creacion
        , fecha_actualizacion
    FROM incidents_with_resolver
)

SELECT * FROM final