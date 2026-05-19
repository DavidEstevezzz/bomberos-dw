{{
    config(
        materialized='view'
    )
}}

WITH horas_extra AS (
    SELECT
        f.id_hora_extra,
        f.id_empleado,
        f.fecha,
        f.horas_diurnas,
        f.horas_nocturnas,
        f.total_horas,
        f.coste_diurno,
        f.coste_nocturno,
        f.coste_total,
        f.tipo_dia,

        df.dia_semana_num,
        df.dia_semana_nombre,
        df.es_fin_de_semana
    FROM {{ ref('fact_horas_extra') }} f
    LEFT JOIN {{ ref('dim_fecha') }} df
        ON f.fecha = df.fecha
    WHERE f.fecha >= '2025-05-05'
      AND f.fecha < '2026-05-05'
),

-- ────────────────────────────────────────────────────────────────────
-- Totales globales del periodo, calculados una sola vez vía CTE para
-- usarlos como denominador en los porcentajes de cada agrupación.
-- Evita window functions sobre cada fila resultado.
-- ────────────────────────────────────────────────────────────────────
totales_globales AS (
    SELECT
        SUM(total_horas) AS total_horas_global,
        SUM(coste_total) AS coste_total_global,
        COUNT(*) AS total_registros_global
    FROM horas_extra
),

-- Agregación primaria: una fila por tipo_dia.
-- Se cruza con totales_globales para calcular cuota relativa.
agregado_tipo_dia AS (
    SELECT
        h.tipo_dia,

        COUNT(*) AS total_registros,
        COUNT(DISTINCT h.id_empleado) AS empleados_distintos,

        SUM(h.horas_diurnas) AS total_horas_diurnas,
        SUM(h.horas_nocturnas) AS total_horas_nocturnas,
        SUM(h.total_horas) AS total_horas,

        ROUND(SUM(h.coste_diurno), 2) AS coste_diurno,
        ROUND(SUM(h.coste_nocturno), 2) AS coste_nocturno,
        ROUND(SUM(h.coste_total), 2) AS coste_total,

        ROUND(AVG(h.total_horas), 2) AS media_horas_por_registro,
        ROUND(AVG(h.coste_total), 2) AS media_coste_por_registro,

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
        ) AS pct_horas_sobre_total

    FROM horas_extra h
    CROSS JOIN totales_globales t
    GROUP BY
        h.tipo_dia,
        t.coste_total_global,
        t.total_horas_global
)

SELECT *
FROM agregado_tipo_dia