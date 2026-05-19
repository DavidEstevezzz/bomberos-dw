{{
    config(
        materialized='view'
    )
}}

WITH incidencias AS (
    SELECT
        id_incidencia,
        tipo_incidencia,
        -- Imputación explícita del nivel_gravedad NULL como 'sin_clasificar'
        -- para mantenerlo en el GROUP BY y poder cuantificar el agujero
        -- de calidad. Mover esta limpieza a stg cambiaría el contrato de la fact.
        COALESCE(nivel_gravedad, 'sin_clasificar') AS nivel_gravedad,
        estado,
        dias_resolucion,
        es_resuelta,
        es_pendiente,
        es_tramitada
    FROM {{ ref('fact_incidencias') }}
    WHERE fecha_incidencia >= '2026-01-01'
      AND fecha_incidencia < '2026-05-05'
),

final AS (
    SELECT
        tipo_incidencia,
        nivel_gravedad,

        COUNT(*) AS total_incidencias,

        SUM(es_resuelta) AS total_resueltas,
        SUM(es_tramitada) AS total_tramitadas,
        SUM(es_pendiente) AS total_pendientes,

        ROUND(
            SUM(es_resuelta) / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_resueltas,

        ROUND(
            SUM(es_tramitada) / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_tramitadas,

        ROUND(
            SUM(es_pendiente) / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS pct_pendientes,

        -- MTTR: solo sobre incidencias resueltas con dias_resolucion válido.
        -- AVG y MEDIAN ignoran NULL por defecto, así que el filtro implícito ya
        -- limita el cálculo a las resueltas (en pendientes/tramitadas dias_resolucion es NULL).
        ROUND(AVG(dias_resolucion), 2)::NUMBER(38,2) AS mttr_dias_medio,
        ROUND(MEDIAN(dias_resolucion), 2)::NUMBER(38,2) AS mttr_dias_mediana,

        MIN(dias_resolucion) AS dias_resolucion_min,
        MAX(dias_resolucion) AS dias_resolucion_max,

        ROUND(STDDEV(dias_resolucion), 2)::NUMBER(38,2) AS desviacion_mttr,

        -- Categorización del rendimiento: facilita filtrar en herramientas BI
        -- sin recalcular umbrales. Los cortes (3, 7, 14 días) son convenciones
        -- razonables para mantenimiento; ajustables si jefatura define SLAs.
        CASE
            WHEN AVG(dias_resolucion) IS NULL THEN 'sin_datos'
            WHEN AVG(dias_resolucion) <= 3 THEN 'rapido'
            WHEN AVG(dias_resolucion) <= 7 THEN 'normal'
            WHEN AVG(dias_resolucion) <= 14 THEN 'lento'
            ELSE 'muy_lento'
        END AS categoria_mttr

    FROM incidencias
    GROUP BY
        tipo_incidencia,
        nivel_gravedad
)

SELECT *
FROM final