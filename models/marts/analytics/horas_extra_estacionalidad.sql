{{
    config(
        materialized='view'
    )
}}

WITH horas_extra AS (
    SELECT
        DATE_TRUNC('month', fecha) AS mes,
        id_hora_extra,
        id_empleado,
        horas_diurnas,
        horas_nocturnas,
        total_horas,
        coste_diurno,
        coste_nocturno,
        coste_total,
        tipo_salario
    FROM {{ ref('fact_horas_extra') }}
    WHERE fecha >= '2025-05-05'
      AND fecha < '2026-05-05'
),

final AS (
    SELECT
        mes,

        COUNT(*) AS total_registros,
        COUNT(DISTINCT id_empleado) AS empleados_distintos,

        SUM(horas_diurnas) AS total_horas_diurnas,
        SUM(horas_nocturnas) AS total_horas_nocturnas,
        SUM(total_horas) AS total_horas,

        ROUND(
            SUM(horas_diurnas) / NULLIF(SUM(total_horas), 0) * 100,
            2
        ) AS pct_horas_diurnas,

        ROUND(
            SUM(horas_nocturnas) / NULLIF(SUM(total_horas), 0) * 100,
            2
        ) AS pct_horas_nocturnas,

        ROUND(SUM(coste_diurno), 2) AS coste_diurno,
        ROUND(SUM(coste_nocturno), 2) AS coste_nocturno,
        ROUND(SUM(coste_total), 2) AS coste_total,

        ROUND(
            SUM(coste_diurno) / NULLIF(SUM(coste_total), 0) * 100,
            2
        ) AS pct_coste_diurno,

        ROUND(
            SUM(coste_nocturno) / NULLIF(SUM(coste_total), 0) * 100,
            2
        ) AS pct_coste_nocturno,

        ROUND(AVG(total_horas), 2) AS media_horas_por_registro,
        ROUND(AVG(coste_total), 2) AS media_coste_por_registro,

        ROUND(
            SUM(coste_total) / NULLIF(SUM(total_horas), 0),
            2
        ) AS coste_medio_por_hora,

        SUM(CASE WHEN tipo_salario = 'Subinspector' THEN coste_total ELSE 0 END) AS coste_subinspector,
        SUM(CASE WHEN tipo_salario = 'Tropa' THEN coste_total ELSE 0 END) AS coste_tropa

    FROM horas_extra
    GROUP BY mes
)

SELECT *
FROM final