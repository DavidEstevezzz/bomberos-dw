{{
    config(
        materialized='view'
    )
}}

WITH incidencias_vehiculo AS (
    SELECT
        f.id_incidencia,
        f.vehiculo_key,
        f.matricula_vehiculo,
        f.tipo_incidencia,
        COALESCE(f.nivel_gravedad, 'sin_clasificar') AS nivel_gravedad,
        f.estado,
        f.dias_resolucion,
        f.es_resuelta,
        f.es_pendiente,
        f.es_tramitada,

        v.nombre_vehiculo,
        v.tipo_vehiculo,
        v.anio_vehiculo,
        v.nombre_parque
    FROM {{ ref('fact_incidencias') }} f
    LEFT JOIN {{ ref('dim_vehiculo') }} v
        ON f.vehiculo_key = v.vehiculo_key
    WHERE f.fecha_incidencia >= '2026-01-01'
      AND f.fecha_incidencia < '2026-05-05'
      -- Solo incidencias asociadas a un vehículo registrado.
      -- Las incidencias sin vehiculo_key serían ruido en este ranking.
      AND f.vehiculo_key IS NOT NULL
      AND f.vehiculo_key <> '-1'
),

agregado_vehiculo AS (
    SELECT
        matricula_vehiculo,
        COALESCE(nombre_vehiculo, 'DESCONOCIDO') AS nombre_vehiculo,
        COALESCE(tipo_vehiculo, 'desconocido') AS tipo_vehiculo,
        anio_vehiculo,
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

        ROUND(AVG(dias_resolucion), 2)::NUMBER(38,2) AS mttr_vehiculo,
        ROUND(MEDIAN(dias_resolucion), 2)::NUMBER(38,2) AS mttr_vehiculo_mediana,

        MIN(dias_resolucion) AS dias_resolucion_min,
        MAX(dias_resolucion) AS dias_resolucion_max
    FROM incidencias_vehiculo
    GROUP BY
        matricula_vehiculo,
        COALESCE(nombre_vehiculo, 'DESCONOCIDO'),
        COALESCE(tipo_vehiculo, 'desconocido'),
        anio_vehiculo,
        COALESCE(nombre_parque, 'DESCONOCIDO')
),

-- Capa de ranking y clasificación de criticidad.
-- "Problemático" = alto volumen O alta proporción de gravedad alta.
-- "Crónico" = pendientes acumuladas sin resolver.
con_ranking AS (
    SELECT
        a.*,

        RANK() OVER (ORDER BY total_incidencias DESC) AS ranking_volumen_global,

        RANK() OVER (
            PARTITION BY nombre_parque
            ORDER BY total_incidencias DESC
        ) AS ranking_volumen_dentro_parque,

        RANK() OVER (
            PARTITION BY tipo_vehiculo
            ORDER BY total_incidencias DESC
        ) AS ranking_volumen_dentro_tipo,

        RANK() OVER (
            ORDER BY incidencias_alta_gravedad DESC, total_incidencias DESC
        ) AS ranking_criticidad,

        -- Clasificación operativa del vehículo:
        -- usa umbrales relativos sobre la media para no fijar números arbitrarios.
        -- Se calcula AVG sobre todos los vehículos del periodo y se compara cada uno.
        ROUND(
            AVG(total_incidencias) OVER (),
            2
        )::NUMBER(38,2) AS media_incidencias_flota,

        CASE
            WHEN total_incidencias >= 2 * AVG(total_incidencias) OVER ()
              AND incidencias_alta_gravedad >= 1
                THEN 'critico'
            WHEN total_incidencias >= AVG(total_incidencias) OVER ()
                THEN 'problematico'
            WHEN total_incidencias >= 0.5 * AVG(total_incidencias) OVER ()
                THEN 'normal'
            ELSE 'bajo_volumen'
        END AS categoria_vehiculo

    FROM agregado_vehiculo a
)

SELECT *
FROM con_ranking