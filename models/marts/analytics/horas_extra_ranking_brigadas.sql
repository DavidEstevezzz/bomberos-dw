{{
    config(
        materialized='view'
    )
}}

WITH horas_extra AS (
    SELECT
        f.id_hora_extra
        , f.id_empleado
        , f.brigada_key
        , f.horas_diurnas
        , f.horas_nocturnas
        , f.total_horas
        , f.coste_diurno
        , f.coste_nocturno
        , f.coste_total
        , f.tipo_dia

        , b.id_brigada
        , b.nombre_brigada
        , b.es_especial
        , b.es_brigada_servicio
        , b.nombre_parque

    FROM {{ ref('fact_horas_extra') }} f
    LEFT JOIN {{ ref('dim_brigada') }} b
        ON f.brigada_key = b.brigada_key

    WHERE f.fecha >= '2025-05-05'
      AND f.fecha < '2026-05-05'
),

totales_globales AS (
    SELECT
        SUM(total_horas) AS total_horas_global
        , SUM(coste_total) AS coste_total_global
    FROM horas_extra
),

agregado_brigada AS (
    SELECT
        MIN(h.id_brigada)::number(38,0) AS id_brigada
        , COALESCE(h.nombre_brigada, 'DESCONOCIDA')::varchar AS nombre_brigada

        -- Como el análisis colapsa Norte/Sur, estos campos se mantienen por contrato,
        -- pero ya no representan una sede física concreta.
        , FALSE::boolean AS es_especial
        , CASE
            WHEN COALESCE(h.nombre_brigada, 'DESCONOCIDA') = 'DESCONOCIDA' THEN FALSE
            ELSE TRUE
          END::boolean AS es_brigada_servicio

        , CASE
            WHEN COALESCE(h.nombre_brigada, 'DESCONOCIDA') = 'DESCONOCIDA' THEN 'DESCONOCIDO'
            ELSE 'Norte/Sur'
          END::varchar AS nombre_parque

        , COUNT(*)::number(38,0) AS total_registros
        , COUNT(DISTINCT h.id_empleado)::number(38,0) AS empleados_distintos

        , SUM(h.horas_diurnas)::number(38,0) AS total_horas_diurnas
        , SUM(h.horas_nocturnas)::number(38,0) AS total_horas_nocturnas
        , SUM(h.total_horas)::number(38,0) AS total_horas

        , ROUND(SUM(h.coste_diurno), 2)::number(12,2) AS coste_diurno
        , ROUND(SUM(h.coste_nocturno), 2)::number(12,2) AS coste_nocturno
        , ROUND(SUM(h.coste_total), 2)::number(12,2) AS coste_total

        , ROUND(SUM(CASE WHEN h.tipo_dia = 'festivo' THEN h.coste_total ELSE 0 END), 2)::number(12,2) AS coste_festivo
        , ROUND(SUM(CASE WHEN h.tipo_dia = 'prefestivo' THEN h.coste_total ELSE 0 END), 2)::number(12,2) AS coste_prefestivo
        , ROUND(SUM(CASE WHEN h.tipo_dia = 'laborable' THEN h.coste_total ELSE 0 END), 2)::number(12,2) AS coste_laborable
        , ROUND(SUM(CASE WHEN h.tipo_dia = 'festivo víspera' THEN h.coste_total ELSE 0 END), 2)::number(12,2) AS coste_festivo_vispera

        , ROUND(AVG(h.coste_total), 2)::number(12,2) AS media_coste_por_registro
        , ROUND(AVG(h.total_horas), 2)::number(12,2) AS media_horas_por_registro

        , ROUND(
            SUM(h.coste_total) / NULLIF(SUM(h.total_horas), 0),
            2
        )::number(12,2) AS coste_medio_por_hora

        , ROUND(
            SUM(h.coste_total) / NULLIF(t.coste_total_global, 0) * 100,
            2
        )::number(12,2) AS pct_coste_sobre_total

        , ROUND(
            SUM(h.total_horas) / NULLIF(t.total_horas_global, 0) * 100,
            2
        )::number(12,2) AS pct_horas_sobre_total

        , RANK() OVER (ORDER BY SUM(h.coste_total) DESC)::number(38,0) AS ranking_coste
        , RANK() OVER (ORDER BY SUM(h.total_horas) DESC)::number(38,0) AS ranking_horas

    FROM horas_extra h
    CROSS JOIN totales_globales t
    GROUP BY
        COALESCE(h.nombre_brigada, 'DESCONOCIDA')
        , t.coste_total_global
        , t.total_horas_global
)

SELECT *
FROM agregado_brigada