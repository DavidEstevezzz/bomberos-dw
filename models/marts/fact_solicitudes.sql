{{
    config(
        materialized='incremental',
        unique_key='solicitud_key',
        on_schema_change='append_new_columns'
    )
}}

WITH 

-- import CTEs
stg_requests AS (
    SELECT * FROM {{ ref('stg_bronze__requests') }}
    {% if is_incremental() %}
        WHERE fecha_actualizacion > (SELECT MAX(fecha_actualizacion) FROM {{ this }})
    {% endif %}
),

stg_assignments AS (
    SELECT * FROM {{ ref('stg_bronze__firefighters_assignments') }}
),

stg_shift_changes AS (
    SELECT * FROM {{ ref('stg_bronze__shift_change_requests') }}
),

-- contar requerimientos generados por cada solicitud
requerimientos_por_solicitud AS (
    SELECT
        id_solicitud
        , COUNT(*) AS total_requerimientos
    FROM stg_assignments
    WHERE es_requerimiento = TRUE
      AND id_solicitud IS NOT NULL
    GROUP BY id_solicitud
),

-- contar asignaciones generadas por cada solicitud
asignaciones_por_solicitud AS (
    SELECT
        id_solicitud
        , COUNT(*) AS total_asignaciones
    FROM stg_assignments
    WHERE id_solicitud IS NOT NULL
    GROUP BY id_solicitud
),

-- enriquecer solicitudes
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
        , COALESCE(req.total_requerimientos, 0) AS total_requerimientos_generados
        , CASE
            WHEN r.fecha_fin IS NOT NULL AND r.fecha_inicio IS NOT NULL
            THEN DATEDIFF('day', r.fecha_inicio, r.fecha_fin) + 1
            ELSE 1
          END AS dias_solicitados
        , r.fecha_creacion
        , r.fecha_actualizacion
    FROM stg_requests r
    LEFT JOIN asignaciones_por_solicitud a
        ON r.id_solicitud = a.id_solicitud
    LEFT JOIN requerimientos_por_solicitud req
        ON r.id_solicitud = req.id_solicitud
),

-- surrogate keys
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_solicitud']) }} AS solicitud_key
        , {{ dbt_utils.generate_surrogate_key(['id_empleado']) }} AS empleado_key_natural
        , {{ dbt_utils.generate_surrogate_key(['fecha_inicio']) }} AS fecha_inicio_key
        , {{ dbt_utils.generate_surrogate_key(['fecha_fin']) }} AS fecha_fin_key
        -- degenerate dimensions
        , id_solicitud
        , id_empleado
        , id_empleado_gestor
        -- atributos del hecho
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
    FROM solicitudes_enriched
)

SELECT * FROM final