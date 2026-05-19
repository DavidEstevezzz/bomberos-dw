{{
    config(
        materialized='view'
    )
}}

WITH incidencias_atascadas AS (
    SELECT
        f.id_incidencia,
        f.tipo_incidencia,
        COALESCE(f.nivel_gravedad, 'sin_clasificar') AS nivel_gravedad,
        f.estado,
        f.fecha_incidencia,
        f.fecha_creacion,
        f.fecha_actualizacion,
        f.id_parque,
        f.id_empleado_creador,
        f.matricula_vehiculo,
        f.id_equipo,
        f.nombre_equipo_comun,

        -- Días atascada: medido desde fecha_creacion hasta hoy.
        -- DATEDIFF con días enteros: precisión suficiente para gestión operativa.
        -- No uso fecha_actualizacion como referencia porque las incidencias
        -- 'tramitadas' pueden haber tenido updates intermedios sin avance real.
        DATEDIFF('day', f.fecha_creacion, CURRENT_DATE())::NUMBER(38,0) AS dias_atascada,

        e.nombre_token AS creador_nombre_token,
        e.puesto AS creador_puesto,
        e.categoria_puesto AS creador_categoria_puesto,

        p.nombre_parque,

        v.nombre_vehiculo,
        v.tipo_vehiculo,

        eq.nombre_equipo,
        eq.categoria_equipo
    FROM {{ ref('fact_incidencias') }} f
    LEFT JOIN {{ ref('dim_empleado') }} e
        ON f.empleado_creador_key = e.empleado_key
    LEFT JOIN {{ ref('dim_parque') }} p
        ON f.id_parque = p.id_parque
    LEFT JOIN {{ ref('dim_vehiculo') }} v
        ON f.vehiculo_key = v.vehiculo_key
    LEFT JOIN {{ ref('dim_equipo') }} eq
        ON f.equipo_key = eq.equipo_key
    -- Sin ventana temporal: el cuello de botella es sobre toda la historia.
    -- Una incidencia abierta hace 8 meses es justo lo que jefatura quiere ver.
    WHERE f.estado IN ('pendiente', 'tramitada')
),

con_clasificacion AS (
    SELECT
        i.*,

        -- Categorización de antigüedad: facilita filtrar en BI por "urgencia".
        -- Los umbrales (7, 30, 90 días) son razonables para mantenimiento de
        -- flota y EPI; pueden ajustarse si jefatura define SLAs distintos.
        CASE
            WHEN dias_atascada <= 7 THEN 'reciente'
            WHEN dias_atascada <= 30 THEN 'una_semana_a_un_mes'
            WHEN dias_atascada <= 90 THEN 'mes_a_trimestre'
            WHEN dias_atascada <= 180 THEN 'trimestre_a_semestre'
            ELSE 'muy_antigua'
        END AS categoria_antiguedad,

        -- Prioridad operativa combinando gravedad + antigüedad.
        -- Es la métrica accionable: jefatura ordena por prioridad y atiende.
        CASE
            WHEN nivel_gravedad = 'alto' AND dias_atascada > 7 THEN 1
            WHEN nivel_gravedad = 'alto' THEN 2
            WHEN nivel_gravedad = 'medio' AND dias_atascada > 30 THEN 3
            WHEN nivel_gravedad = 'medio' THEN 4
            WHEN dias_atascada > 90 THEN 5
            WHEN nivel_gravedad = 'bajo' AND dias_atascada > 30 THEN 6
            ELSE 7
        END AS prioridad_atencion

    FROM incidencias_atascadas i
),

-- Capa final con ranking por antigüedad para presentar tipo "top-N".
-- ROW_NUMBER en lugar de RANK porque queremos un orden estricto sin empates
-- (cada incidencia es única, no agregamos).
final AS (
    SELECT
        c.*,

        ROW_NUMBER() OVER (
            ORDER BY dias_atascada DESC, prioridad_atencion ASC
        ) AS ranking_antiguedad_global,

        ROW_NUMBER() OVER (
            PARTITION BY tipo_incidencia
            ORDER BY dias_atascada DESC
        ) AS ranking_antiguedad_dentro_tipo,

        ROW_NUMBER() OVER (
            PARTITION BY nombre_parque
            ORDER BY dias_atascada DESC
        ) AS ranking_antiguedad_dentro_parque

    FROM con_clasificacion c
)

SELECT *
FROM final