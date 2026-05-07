{{
    config(
        materialized='view'
    )
}}

WITH solicitudes AS (
    SELECT
        DATE_TRUNC('month', fecha_inicio) AS mes,
        tipo_permiso,
        estado,
        id_solicitud,
        id_empleado,
        dias_solicitados
    FROM {{ ref('fact_solicitudes') }}
    WHERE fecha_inicio >= '2026-01-01'
      AND fecha_inicio < '2026-05-05'
),

final AS (
    SELECT
        mes,
        tipo_permiso,

        COUNT(*) AS total_solicitudes,
        COUNT(DISTINCT id_empleado) AS empleados_distintos,

        COUNT_IF(estado = 'confirmada') AS solicitudes_confirmadas,
        COUNT_IF(estado = 'denegada') AS solicitudes_denegadas,
        COUNT_IF(estado = 'cancelada') AS solicitudes_canceladas,
        COUNT_IF(estado = 'pendiente') AS solicitudes_pendientes,

        SUM(dias_solicitados) AS total_dias_solicitados,

        SUM(
            CASE
                WHEN estado = 'confirmada' THEN dias_solicitados
                ELSE 0
            END
        ) AS dias_confirmados,

        SUM(
            CASE
                WHEN estado = 'denegada' THEN dias_solicitados
                ELSE 0
            END
        ) AS dias_denegados,

        ROUND(AVG(dias_solicitados), 2) AS media_dias_por_solicitud

    FROM solicitudes
    GROUP BY
        mes,
        tipo_permiso
)

SELECT *
FROM final