{{
    config(
        materialized='view'
    )
}}

WITH incidencias_resueltas AS (
    SELECT
        f.id_incidencia,
        f.id_empleado_resolutor,
        f.empleado_resolutor_key,
        f.id_parque,
        f.tipo_incidencia,
        COALESCE(f.nivel_gravedad, 'sin_clasificar') AS nivel_gravedad,
        f.dias_resolucion,

        -- Atributos SCD2 del resolutor en el momento de la resolución:
        -- el JOIN se hace por empleado_resolutor_key, que fact_incidencias
        -- ya resuelve point-in-time con fecha_efecto_resolutor.
        -- Si un bombero se promocionó tras resolver una incidencia,
        -- la incidencia se atribuye al puesto que tenía AL RESOLVERLA.
        e.nombre_token,
        e.categoria_puesto,
        e.puesto,

        p.nombre_parque
    FROM {{ ref('fact_incidencias') }} f
    LEFT JOIN {{ ref('dim_empleado') }} e
        ON f.empleado_resolutor_key = e.empleado_key
    LEFT JOIN {{ ref('dim_parque') }} p
        ON f.id_parque = p.id_parque
    WHERE f.fecha_incidencia >= '2026-01-01'
      AND f.fecha_incidencia < '2026-05-05'
      -- Solo incidencias efectivamente resueltas con resolutor conocido:
      -- sin resolutor no hay nada que rankear.
      AND f.estado = 'resuelta'
      AND f.empleado_resolutor_key IS NOT NULL
      AND f.empleado_resolutor_key <> '-1'
),

agregado_resolutor AS (
    SELECT
        id_empleado_resolutor,
        COALESCE(nombre_token, 'DESCONOCIDO') AS nombre_token,
        COALESCE(categoria_puesto, 'desconocido') AS categoria_puesto,
        COALESCE(puesto, 'desconocido') AS puesto,
        COALESCE(nombre_parque, 'DESCONOCIDO') AS nombre_parque,

        COUNT(*) AS total_resueltas,

        -- Distribución por tipo de incidencia: ayuda a detectar especialización
        -- (un bombero que resuelve sobre todo vehículos vs uno generalista).
        SUM(CASE WHEN tipo_incidencia = 'vehiculo' THEN 1 ELSE 0 END) AS resueltas_vehiculo,
        SUM(CASE WHEN tipo_incidencia = 'personal' THEN 1 ELSE 0 END) AS resueltas_personal,
        SUM(CASE WHEN tipo_incidencia = 'equipo' THEN 1 ELSE 0 END) AS resueltas_equipo,
        SUM(CASE WHEN tipo_incidencia = 'instalacion' THEN 1 ELSE 0 END) AS resueltas_instalacion,
        SUM(CASE WHEN tipo_incidencia = 'vestuario' THEN 1 ELSE 0 END) AS resueltas_vestuario,
        SUM(CASE WHEN tipo_incidencia = 'equipos_comunes' THEN 1 ELSE 0 END) AS resueltas_equipos_comunes,

        SUM(CASE WHEN nivel_gravedad = 'alto' THEN 1 ELSE 0 END) AS resueltas_alta_gravedad,
        SUM(CASE WHEN nivel_gravedad = 'medio' THEN 1 ELSE 0 END) AS resueltas_media_gravedad,
        SUM(CASE WHEN nivel_gravedad = 'bajo' THEN 1 ELSE 0 END) AS resueltas_baja_gravedad,

        ROUND(AVG(dias_resolucion), 2)::NUMBER(38,2) AS mttr_personal,
        ROUND(MEDIAN(dias_resolucion), 2)::NUMBER(38,2) AS mttr_personal_mediana,
        MIN(dias_resolucion) AS dias_resolucion_min,
        MAX(dias_resolucion) AS dias_resolucion_max

    FROM incidencias_resueltas
    GROUP BY
        id_empleado_resolutor,
        COALESCE(nombre_token, 'DESCONOCIDO'),
        COALESCE(categoria_puesto, 'desconocido'),
        COALESCE(puesto, 'desconocido'),
        COALESCE(nombre_parque, 'DESCONOCIDO')
),

-- Capa de window functions: rankings y benchmarking dentro del puesto y del parque.
-- Mismo patrón que horas_extra_ranking_empleados: comparar dentro del grupo natural
-- (puesto), no globalmente, para que la comparación sea justa.
con_ranking AS (
    SELECT
        a.*,

        RANK() OVER (ORDER BY total_resueltas DESC) AS ranking_total_global,
        RANK() OVER (
            PARTITION BY nombre_parque
            ORDER BY total_resueltas DESC
        ) AS ranking_total_dentro_parque,
        RANK() OVER (
            PARTITION BY puesto
            ORDER BY total_resueltas DESC
        ) AS ranking_total_dentro_puesto,

        -- Ranking por MTTR ASCENDENTE: el mejor es el que tarda menos.
        -- Solo se considera si tiene >= 3 incidencias resueltas para evitar
        -- que un resolutor con 1 incidencia rápida domine el ranking.
        RANK() OVER (
            ORDER BY
                CASE WHEN total_resueltas >= 3 THEN mttr_personal END ASC NULLS LAST
        ) AS ranking_velocidad_global,

        ROUND(
            AVG(mttr_personal) OVER (PARTITION BY puesto),
            2
        )::NUMBER(38,2) AS mttr_medio_puesto,

        ROUND(
            AVG(mttr_personal) OVER (PARTITION BY nombre_parque),
            2
        )::NUMBER(38,2) AS mttr_medio_parque,

        COUNT(*) OVER (PARTITION BY puesto) AS resolutores_en_puesto,
        COUNT(*) OVER (PARTITION BY nombre_parque) AS resolutores_en_parque,

        ROUND(
            total_resueltas / NULLIF(
                SUM(total_resueltas) OVER (PARTITION BY nombre_parque),
                0
            ) * 100,
            2
        )::NUMBER(38,2) AS pct_resueltas_sobre_parque

    FROM agregado_resolutor a
)

SELECT *
FROM con_ranking