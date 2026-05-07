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
        dias_solicitados,
        fecha_inicio,
        fecha_actualizacion
    FROM {{ ref('fact_solicitudes') }}
    WHERE fecha_inicio >= '2026-01-01'
      AND fecha_inicio < '2026-05-05'
),

final AS (
    SELECT
        tipo_permiso,

        COUNT(*) AS total_solicitudes,

        COUNT_IF(estado = 'confirmada') AS solicitudes_confirmadas,
        COUNT_IF(estado = 'denegada') AS solicitudes_denegadas,
        COUNT_IF(estado = 'cancelada') AS solicitudes_canceladas,
        COUNT_IF(estado = 'pendiente') AS solicitudes_pendientes,

        ROUND(
            COUNT_IF(estado = 'confirmada') / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_confirmadas,

        ROUND(
            COUNT_IF(estado = 'denegada') / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_denegadas,

        ROUND(
            COUNT_IF(estado = 'cancelada') / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_canceladas,

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

        ROUND(
            AVG(
                CASE
                    WHEN estado = 'confirmada'
                     AND fecha_actualizacion IS NOT NULL
                     AND fecha_inicio IS NOT NULL
                    THEN DATEDIFF('day', fecha_actualizacion, fecha_inicio)
                END
            ),
            2
        ) AS media_dias_antelacion_aprobacion,

        MEDIAN(
            CASE
                WHEN estado = 'confirmada'
                 AND fecha_actualizacion IS NOT NULL
                 AND fecha_inicio IS NOT NULL
                THEN DATEDIFF('day', fecha_actualizacion, fecha_inicio)
            END
        ) AS mediana_dias_antelacion_aprobacion,

        COUNT_IF(
            estado = 'confirmada'
            AND DATEDIFF('day', fecha_actualizacion, fecha_inicio) < 0
        ) AS aprobadas_despues_inicio,

        COUNT_IF(
            estado = 'confirmada'
            AND DATEDIFF('day', fecha_actualizacion, fecha_inicio) BETWEEN 0 AND 2
        ) AS aprobadas_con_0_2_dias_antelacion

    FROM solicitudes
    GROUP BY tipo_permiso
    HAVING COUNT(*) >= 5
)

SELECT *
FROM final