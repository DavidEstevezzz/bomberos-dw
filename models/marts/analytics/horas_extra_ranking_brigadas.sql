{{
    config(
        materialized='view'
    )
}}

WITH horas_extra AS (
    SELECT
        f.id_hora_extra,
        f.id_empleado,
        f.brigada_key,
        f.horas_diurnas,
        f.horas_nocturnas,
        f.total_horas,
        f.coste_diurno,
        f.coste_nocturno,
        f.coste_total,
        f.tipo_dia,

        b.id_brigada,
        b.nombre_brigada,
        b.es_especial,
        b.es_brigada_servicio,
        b.nombre_parque
    FROM {{ ref('fact_horas_extra') }} f
    LEFT JOIN {{ ref('dim_brigada') }} b
        ON f.brigada_key = b.brigada_key
    WHERE f.fecha >= '2025-05-05'
      AND f.fecha < '2026-05-05'
),

totales_globales AS (
    SELECT
        SUM(total_horas) AS total_horas_global,
        SUM(coste_total) AS coste_total_global
    FROM horas_extra
),

agregado_brigada AS (
    SELECT
        h.id_brigada,
        COALESCE(h.nombre_brigada, 'DESCONOCIDA') AS nombre_brigada,
        COALESCE(h.es_especial, FALSE) AS es_especial,
        COALESCE(h.es_brigada_servicio, FALSE) AS es_brigada_servicio,
        COALESCE(h.nombre_parque, 'DESCONOCIDO') AS nombre_parque,

        COUNT(*) AS total_registros,
        COUNT(DISTINCT h.id_empleado) AS empleados_distintos,

        SUM(h.horas_diurnas) AS total_horas_diurnas,
        SUM(h.horas_nocturnas) AS total_horas_nocturnas,
        SUM(h.total_horas) AS total_horas,

        ROUND(SUM(h.coste_diurno), 2) AS coste_diurno,
        ROUND(SUM(h.coste_nocturno), 2) AS coste_nocturno,
        ROUND(SUM(h.coste_total), 2) AS coste_total,

        -- Desglose de horas por tipo_dia: permite ver dónde se concentra
        -- el gasto de cada brigada (festivos vs laborables) sin necesidad
        -- de un GROUP BY adicional aguas abajo.
        SUM(CASE WHEN h.tipo_dia = 'festivo' THEN h.coste_total ELSE 0 END) AS coste_festivo,
        SUM(CASE WHEN h.tipo_dia = 'prefestivo' THEN h.coste_total ELSE 0 END) AS coste_prefestivo,
        SUM(CASE WHEN h.tipo_dia = 'laborable' THEN h.coste_total ELSE 0 END) AS coste_laborable,
        SUM(CASE WHEN h.tipo_dia = 'festivo víspera' THEN h.coste_total ELSE 0 END) AS coste_festivo_vispera,

        ROUND(AVG(h.coste_total), 2) AS media_coste_por_registro,
        ROUND(AVG(h.total_horas), 2) AS media_horas_por_registro,

        ROUND(
            SUM(h.coste_total) / NULLIF(SUM(h.total_horas), 0),
            2
        ) AS coste_medio_por_hora,

        ROUND(
            SUM(h.coste_total) / NULLIF(t.coste_total_global, 0) * 100,
            2
        ) AS pct_coste_sobre_total,

        ROUND(
            SUM(h.total_horas) / NULLIF(t.total_horas_global, 0) * 100,
            2
        ) AS pct_horas_sobre_total,

        -- Ranking absoluto por coste total dentro del periodo, en una
        -- sola pasada vía window function. Permite filtrar top-N
        -- directamente en herramientas BI sin recalcular.
        RANK() OVER (ORDER BY SUM(h.coste_total) DESC) AS ranking_coste,
        RANK() OVER (ORDER BY SUM(h.total_horas) DESC) AS ranking_horas

    FROM horas_extra h
    CROSS JOIN totales_globales t
    GROUP BY
        h.id_brigada,
        COALESCE(h.nombre_brigada, 'DESCONOCIDA'),
        COALESCE(h.es_especial, FALSE),
        COALESCE(h.es_brigada_servicio, FALSE),
        COALESCE(h.nombre_parque, 'DESCONOCIDO'),
        t.coste_total_global,
        t.total_horas_global
)

SELECT *
FROM agregado_brigada