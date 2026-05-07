{{
    config(
        materialized='view'
    )
}}

WITH solicitudes AS (
    SELECT
        s.id_empleado,
        s.empleado_key,
        s.tipo_permiso,
        s.estado,
        s.id_solicitud,
        s.dias_solicitados,
        s.fecha_inicio,

        e.nombre_token,
        e.categoria_puesto,
        e.puesto

    FROM {{ ref('fact_solicitudes') }} s
    LEFT JOIN {{ ref('dim_empleado') }} e
        ON s.empleado_key = e.empleado_key
    WHERE s.fecha_inicio >= '2025-05-05'
      AND s.fecha_inicio < '2026-05-05'
),

final AS (
    SELECT
        id_empleado,
        COALESCE(nombre_token, 'DESCONOCIDO') AS nombre_token,
        COALESCE(categoria_puesto, 'desconocido') AS categoria_puesto,
        COALESCE(puesto, 'desconocido') AS puesto,

        COUNT(*) AS total_solicitudes,

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

        SUM(
            CASE
                WHEN estado = 'cancelada' THEN dias_solicitados
                ELSE 0
            END
        ) AS dias_cancelados,

        SUM(
            CASE
                WHEN estado = 'pendiente' THEN dias_solicitados
                ELSE 0
            END
        ) AS dias_pendientes,

        ROUND(
            COUNT_IF(estado = 'confirmada') / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_confirmadas,

        ROUND(
            COUNT_IF(estado = 'denegada') / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_denegadas,

        ROUND(AVG(dias_solicitados), 2) AS media_dias_por_solicitud,

        COUNT(DISTINCT tipo_permiso) AS tipos_permiso_distintos,

        LISTAGG(DISTINCT tipo_permiso, ', ')
            WITHIN GROUP (ORDER BY tipo_permiso) AS tipos_permiso_usados

    FROM solicitudes
    GROUP BY
        id_empleado,
        COALESCE(nombre_token, 'DESCONOCIDO'),
        COALESCE(categoria_puesto, 'desconocido'),
        COALESCE(puesto, 'desconocido')
)

SELECT *
FROM final