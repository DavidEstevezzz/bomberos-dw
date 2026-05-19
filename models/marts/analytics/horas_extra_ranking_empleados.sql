{{
    config(
        materialized='view'
    )
}}

WITH horas_extra AS (
    SELECT
        f.id_hora_extra,
        f.id_empleado,
        f.empleado_key,
        f.horas_diurnas,
        f.horas_nocturnas,
        f.total_horas,
        f.coste_diurno,
        f.coste_nocturno,
        f.coste_total,
        f.tipo_dia,

        -- Atributos del empleado en el momento del hecho (SCD2 point-in-time):
        -- si el bombero cambió de puesto durante el periodo, los registros
        -- previos al cambio se agregan bajo su puesto histórico.
        e.nombre_token,
        e.categoria_puesto,
        e.puesto
    FROM {{ ref('fact_horas_extra') }} f
    LEFT JOIN {{ ref('dim_empleado') }} e
        ON f.empleado_key = e.empleado_key
    WHERE f.fecha >= '2026-01-01'
      AND f.fecha < '2026-05-05'
),

-- Agregación primaria por empleado.
-- Las window functions de ranking se aplican PARTITION BY puesto
-- para permitir comparar justo dentro de cada categoría.
agregado_empleado AS (
    SELECT
        id_empleado,
        COALESCE(nombre_token, 'DESCONOCIDO') AS nombre_token,
        COALESCE(categoria_puesto, 'desconocido') AS categoria_puesto,
        COALESCE(puesto, 'desconocido') AS puesto,

        COUNT(*) AS total_registros,

        SUM(horas_diurnas) AS total_horas_diurnas,
        SUM(horas_nocturnas) AS total_horas_nocturnas,
        SUM(total_horas) AS total_horas,

        ROUND(SUM(coste_diurno), 2) AS coste_diurno,
        ROUND(SUM(coste_nocturno), 2) AS coste_nocturno,
        ROUND(SUM(coste_total), 2) AS coste_total,

        SUM(CASE WHEN tipo_dia = 'festivo' THEN total_horas ELSE 0 END) AS horas_festivo,
        SUM(CASE WHEN tipo_dia = 'prefestivo' THEN total_horas ELSE 0 END) AS horas_prefestivo,
        SUM(CASE WHEN tipo_dia = 'laborable' THEN total_horas ELSE 0 END) AS horas_laborable,
        SUM(CASE WHEN tipo_dia = 'festivo víspera' THEN total_horas ELSE 0 END) AS horas_festivo_vispera,

        ROUND(AVG(total_horas), 2) AS media_horas_por_registro,
        ROUND(AVG(coste_total), 2) AS media_coste_por_registro

    FROM horas_extra
    GROUP BY
        id_empleado,
        COALESCE(nombre_token, 'DESCONOCIDO'),
        COALESCE(categoria_puesto, 'desconocido'),
        COALESCE(puesto, 'desconocido')
),

-- Capa de window functions: ranking y posicionamiento dentro del puesto.
-- Separar esta lógica permite leer la query principal con menos ruido
-- y reutilizar las agregaciones en los percentiles relativos.
con_ranking AS (
    SELECT
        a.*,

        -- Ranking dentro del puesto (comparación "justa").
        RANK() OVER (
            PARTITION BY puesto
            ORDER BY coste_total DESC
        ) AS ranking_coste_dentro_puesto,

        RANK() OVER (
            PARTITION BY puesto
            ORDER BY total_horas DESC
        ) AS ranking_horas_dentro_puesto,

        -- Ranking global (sin partición). Útil para detectar
        -- bomberos que sobresalen incluso comparados con todo el cuerpo.
        RANK() OVER (
            ORDER BY coste_total DESC
        ) AS ranking_coste_global,

        -- Estadísticos del puesto para contextualizar a cada empleado.
        -- Permiten responder "¿está este bombero por encima de la
        -- media de su puesto?" sin un JOIN adicional.
        ROUND(
            AVG(coste_total) OVER (PARTITION BY puesto),
            2
        ) AS coste_medio_puesto,

        ROUND(
            AVG(total_horas) OVER (PARTITION BY puesto),
            2
        ) AS horas_medias_puesto,

        ROUND(
            STDDEV(coste_total) OVER (PARTITION BY puesto),
            2
        ) AS desviacion_coste_puesto,

        COUNT(*) OVER (PARTITION BY puesto) AS empleados_en_puesto,

        ROUND(
            coste_total / NULLIF(
                SUM(coste_total) OVER (PARTITION BY puesto),
                0
            ) * 100,
            2
        ) AS pct_coste_sobre_puesto,

        -- Desviación normalizada (z-score) sobre el puesto. > 2 ≈ outlier alto,
        -- < -2 ≈ outlier bajo. Útil para detectar concentraciones anómalas
        -- de horas extra en bomberos concretos dentro de su categoría.
        ROUND(
            (coste_total - AVG(coste_total) OVER (PARTITION BY puesto))
                / NULLIF(STDDEV(coste_total) OVER (PARTITION BY puesto), 0),
            2
        ) AS z_score_coste_puesto

    FROM agregado_empleado a
)

SELECT *
FROM con_ranking