{{
    config(
        materialized='incremental',
        unique_key='incidencia_key',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

WITH 

stg_incidents AS (
    SELECT * FROM {{ ref('stg_bronze__incidents') }}

    {% if is_incremental() %}
        -- Lookback window para capturar correcciones retroactivas.
        -- El MERGE absorbe duplicados actualizando filas existentes.
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

-- Fecha de efecto del resolutor:
-- solo existe si la incidencia está resuelta y hay empleado resolutor.
incidents_with_resolution_date AS (
    SELECT
        i.*
        , CASE
            WHEN i.estado = 'resuelta'
              AND i.id_empleado_resolutor IS NOT NULL
            THEN i.fecha_actualizacion
            ELSE NULL
          END AS fecha_efecto_resolutor
    FROM stg_incidents i
),

-- Doble lookup point-in-time contra dim_empleado SCD2:
--   - creador: versión vigente en fecha_incidencia
--   - resolutor: versión vigente en fecha_efecto_resolutor
incidents_with_empleados AS (
    SELECT
        i.*
        , {{ lookup_empleado_scd2('i.id_empleado_creador', 'i.fecha_incidencia', alias='dec') }} AS empleado_creador_key

        , CASE
            WHEN i.id_empleado_resolutor IS NOT NULL
              AND i.fecha_efecto_resolutor IS NOT NULL
            THEN {{ lookup_empleado_scd2('i.id_empleado_resolutor', 'i.fecha_efecto_resolutor', alias='der') }}
            ELSE NULL
          END AS empleado_resolutor_key

    FROM incidents_with_resolution_date i

    LEFT JOIN {{ ref('dim_empleado') }} dec
        {{ join_empleado_scd2('i.id_empleado_creador', 'i.fecha_incidencia', alias='dec') }}

    LEFT JOIN {{ ref('dim_empleado') }} der
        {{ join_empleado_scd2('i.id_empleado_resolutor', 'i.fecha_efecto_resolutor', alias='der') }}
),

final AS (
    SELECT
        -- Surrogate keys
        {{ dbt_utils.generate_surrogate_key(['id_incidencia']) }}::varchar AS incidencia_key
        , empleado_creador_key::varchar AS empleado_creador_key
        , empleado_resolutor_key::varchar AS empleado_resolutor_key
        , {{ dbt_utils.generate_surrogate_key(['fecha_incidencia']) }}::varchar AS fecha_key
        , {{ dbt_utils.generate_surrogate_key(['id_parque']) }}::varchar AS parque_key

        , CASE
            WHEN matricula_vehiculo IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['matricula_vehiculo']) }}
            ELSE NULL
          END::varchar AS vehiculo_key

        , CASE
            WHEN id_equipo IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['id_equipo']) }}
            ELSE NULL
          END::varchar AS equipo_key

        -- Degenerate dimensions / claves naturales
        , id_incidencia::number(38,0) AS id_incidencia
        , id_empleado_creador::number(38,0) AS id_empleado_creador
        , TRY_TO_NUMBER(id_empleado_resolutor)::number(38,0) AS id_empleado_resolutor
        , TRY_TO_NUMBER(id_empleado_referenciado)::number(38,0) AS id_empleado_referenciado
        , fecha_incidencia::date AS fecha_incidencia
        , id_parque::number(38,0) AS id_parque
        , matricula_vehiculo::varchar AS matricula_vehiculo
        , TRY_TO_NUMBER(id_equipo)::number(38,0) AS id_equipo
        , nombre_equipo_comun::varchar AS nombre_equipo_comun

        -- Atributos
        , tipo_incidencia::varchar AS tipo_incidencia
        , estado::varchar AS estado
        , nivel_gravedad::varchar AS nivel_gravedad
        , esta_leido::boolean AS esta_leido

        -- Medidas
        , dias_resolucion::number(38,0) AS dias_resolucion
        , CASE WHEN estado = 'resuelta' THEN 1 ELSE 0 END::number(38,0) AS es_resuelta
        , CASE WHEN estado = 'pendiente' THEN 1 ELSE 0 END::number(38,0) AS es_pendiente
        , CASE WHEN estado = 'tramitada' THEN 1 ELSE 0 END::number(38,0) AS es_tramitada

        -- Auditoría
        , fecha_creacion::timestamp_ntz AS fecha_creacion
        , fecha_actualizacion::timestamp_ntz AS fecha_actualizacion
        , fecha_carga_bronze::timestamp_ntz AS fecha_carga_bronze

    FROM incidents_with_empleados
)

SELECT * FROM final