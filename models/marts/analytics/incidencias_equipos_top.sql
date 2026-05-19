{{
    config(
        materialized='view'
    )
}}

WITH incidencias_equipo AS (
    SELECT
        f.id_incidencia,
        f.equipo_key,
        f.id_equipo,
        f.tipo_incidencia,
        COALESCE(f.nivel_gravedad, 'sin_clasificar') AS nivel_gravedad,
        f.estado,
        f.dias_resolucion,
        f.es_resuelta,
        f.es_pendiente,
        f.es_tramitada,

        e.nombre_equipo,
        e.categoria_equipo,
        e.esta_disponible,
        e.nombre_parque
    FROM {{ ref('fact_incidencias') }} f
    LEFT JOIN {{ ref('dim_equipo') }} e
        ON f.equipo_key = e.equipo_key
    WHERE f.fecha_incidencia >= '2026-01-01'
      AND f.fecha_incidencia < '2026-05-05'
      -- Solo equipos personales registrados en dim_equipo.
      -- Los equipos comunes vienen en nombre_equipo_comun (texto libre)
      -- y son una entidad distinta; se analizarían en otro modelo si interesa.
      AND f.equipo_key IS NOT NULL
      AND f.equipo_key <> '-1'
),

agregado_equipo AS (
    SELECT
        id_equipo,
        COALESCE(nombre_equipo, 'DESCONOCIDO') AS nombre_equipo,
        COALESCE(categoria_equipo, 'desconocido') AS categoria_equipo,
        COALESCE(esta_disponible, FALSE) AS esta_disponible,
        COALESCE(nombre_parque, 'DESCONOCIDO') AS nombre_parque,

        COUNT(*) AS total_incidencias,

        SUM(es_resuelta) AS total_resueltas,
        SUM(es_tramitada) AS total_tramitadas,
        SUM(es_pendiente) AS total_pendientes,

        SUM(CASE WHEN nivel_gravedad = 'alto' THEN 1 ELSE 0 END) AS incidencias_alta_gravedad,
        SUM(CASE WHEN nivel_gravedad = 'medio' THEN 1 ELSE 0 END) AS incidencias_media_gravedad,
        SUM(CASE WHEN nivel_gravedad = 'bajo' THEN 1 ELSE 0 END) AS incidencias_baja_gravedad,
        SUM(CASE WHEN nivel_gravedad = 'sin_clasificar' THEN 1 ELSE 0 END) AS incidencias_sin_clasificar,

        ROUND(
            SUM(es_resuelta) / NULLIF(COUNT(*), 0) * 100,
            2
        )::NUMBER(38,2) AS pct_resueltas,

        ROUND(
            SUM(es_pendiente) / NULLIF(COUNT(*), 0) * 100,
            2
        )::NUMBER(38,2) AS pct_pendientes,

        ROUND(AVG(dias_resolucion), 2)::NUMBER(38,2) AS mttr_equipo,
        ROUND(MEDIAN(dias_resolucion), 2)::NUMBER(38,2) AS mttr_equipo_mediana,

        MIN(dias_resolucion) AS dias_resolucion_min,
        MAX(dias_resolucion) AS dias_resolucion_max
    FROM incidencias_equipo
    GROUP BY
        id_equipo,
        COALESCE(nombre_equipo, 'DESCONOCIDO'),
        COALESCE(categoria_equipo, 'desconocido'),
        COALESCE(esta_disponible, FALSE),
        COALESCE(nombre_parque, 'DESCONOCIDO')
),

-- Capa de ranking dentro de la categoría: cada tipo de equipo (EPI,
-- herramientas, comunicaciones...) tiene patrones de uso muy distintos,
-- así que comparar dentro de la categoría es lo justo.
con_ranking AS (
    SELECT
        a.*,

        RANK() OVER (ORDER BY total_incidencias DESC) AS ranking_volumen_global,

        RANK() OVER (
            PARTITION BY categoria_equipo
            ORDER BY total_incidencias DESC
        ) AS ranking_volumen_dentro_categoria,

        RANK() OVER (
            PARTITION BY nombre_parque
            ORDER BY total_incidencias DESC
        ) AS ranking_volumen_dentro_parque,

        ROUND(
            AVG(total_incidencias) OVER (PARTITION BY categoria_equipo),
            2
        )::NUMBER(38,2) AS media_incidencias_categoria,

        ROUND(
            total_incidencias / NULLIF(
                SUM(total_incidencias) OVER (PARTITION BY categoria_equipo),
                0
            ) * 100,
            2
        )::NUMBER(38,2) AS pct_incidencias_sobre_categoria,

        -- Clasificación operativa basada en si el equipo sigue activo
        -- y su volumen relativo. Útil para decidir reemplazos.
        CASE
            WHEN total_incidencias >= 3 AND COALESCE(esta_disponible, FALSE) = FALSE
                THEN 'retirado_problematico'
            WHEN total_incidencias >= 2 * AVG(total_incidencias) OVER (PARTITION BY categoria_equipo)
              AND incidencias_alta_gravedad >= 1
                THEN 'critico'
            WHEN total_incidencias >= AVG(total_incidencias) OVER (PARTITION BY categoria_equipo)
                THEN 'frecuente'
            ELSE 'normal'
        END AS categoria_equipo_riesgo

    FROM agregado_equipo a
)

SELECT *
FROM con_ranking