
{{
    config(
        materialized='incremental',
        unique_key='solicitud_key',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

WITH 

stg_requests AS (
    SELECT * FROM {{ ref('stg_bronze__requests') }}
    {% if is_incremental() %}
        -- Lookback window para correcciones retroactivas (MERGE absorbe duplicados)
        WHERE fecha_actualizacion >= DATEADD(
            day,
            -{{ var('reprocess_days', 7) }},
            (SELECT MAX(fecha_actualizacion) FROM {{ this }})
        )
    {% endif %}
),

stg_assignments AS (
    SELECT * FROM {{ ref('stg_bronze__firefighters_assignments') }}
),

-- Conditional aggregation: dos métricas en un solo escaneo de stg_assignments
-- en lugar de dos GROUP BY independientes. COUNT(CASE WHEN ...) ignora NULL,
-- por lo que solo cuenta filas donde es_requerimiento es TRUE.
agregados_por_solicitud AS (
    SELECT
        id_solicitud
        , COUNT(*) AS total_asignaciones
        , COUNT(CASE WHEN es_requerimiento THEN 1 END) AS total_requerimientos
    FROM stg_assignments
    WHERE id_solicitud IS NOT NULL
    GROUP BY id_solicitud
),

solicitudes_enriched AS (
    SELECT
        r.id_solicitud
        , r.id_empleado
        , r.id_empleado_gestor
        , r.tipo_permiso
        , r.fecha_inicio
        , r.fecha_fin
        , r.horas_solicitadas
        , r.turno
        , r.estado
        , COALESCE(a.total_asignaciones, 0) AS total_asignaciones_generadas
        , COALESCE(a.total_requerimientos, 0) AS total_requerimientos_generados
        -- Duración inclusiva (+1 para contar ambos extremos).
        -- ELSE 1: solicitudes sin rango de fechas representan 1 día parcial 
        -- (medido en horas_solicitadas).
        , CASE
            WHEN r.fecha_fin IS NOT NULL AND r.fecha_inicio IS NOT NULL
            THEN DATEDIFF('day', r.fecha_inicio, r.fecha_fin) + 1
            ELSE 1
          END AS dias_solicitados
        , r.fecha_creacion
        , r.fecha_actualizacion
        , r.fecha_carga_bronze
    FROM stg_requests r
    LEFT JOIN agregados_por_solicitud a
        ON r.id_solicitud = a.id_solicitud
),

-- Point-in-time SCD2 lookup contra dim_empleado vigente en fecha_inicio
solicitudes_with_empleado AS (
    SELECT
        s.*
        , {{ lookup_empleado_scd2('s.id_empleado', 's.fecha_inicio') }} AS empleado_key
    FROM solicitudes_enriched s
    LEFT JOIN {{ ref('dim_empleado') }} de
        {{ join_empleado_scd2('s.id_empleado', 's.fecha_inicio') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_solicitud']) }} AS solicitud_key
        , empleado_key

        -- Role-playing dimensions: dos FKs distintas hacia la misma dim_fecha.
        -- Permite queries como "duración media entre solicitud y aprobación"
        -- sin necesidad de mantener dos dimensiones físicas.
        , CASE
            WHEN fecha_inicio IS NOT NULL
            THEN {{ dbt_utils.generate_surrogate_key(['fecha_inicio']) }}
            ELSE NULL
          END AS fecha_inicio_key

        , CASE 
            WHEN fecha_fin IS NOT NULL 
            THEN {{ dbt_utils.generate_surrogate_key(['fecha_fin']) }}
            ELSE NULL
          END AS fecha_fin_key

        -- degenerate dimensions
        , id_solicitud
        , id_empleado
        , id_empleado_gestor

        -- atributos
        , tipo_permiso
        , turno
        , estado
        , fecha_inicio
        , fecha_fin

        -- medidas
        , horas_solicitadas
        , dias_solicitados
        , total_asignaciones_generadas
        , total_requerimientos_generados

        -- auditoría
        , fecha_creacion
        , fecha_actualizacion
        , fecha_carga_bronze
    FROM solicitudes_with_empleado
)

SELECT * FROM final