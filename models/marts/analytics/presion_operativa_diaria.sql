{{
    config(
        materialized='view'
    )
}}

WITH fechas AS (
    SELECT
        fecha,
        tipo_dia
    FROM {{ ref('dim_fecha') }}
),

permisos_activos_dia AS (
    SELECT
        f.fecha,

        COUNT(DISTINCT s.id_solicitud) AS permisos_activos_total,

        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'vacaciones' THEN s.id_solicitud END) AS permisos_vacaciones,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'asuntos propios' THEN s.id_solicitud END) AS permisos_asuntos_propios,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'horas sindicales' THEN s.id_solicitud END) AS permisos_horas_sindicales,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'salidas personales' THEN s.id_solicitud END) AS permisos_salidas_personales,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'vestuario' THEN s.id_solicitud END) AS permisos_vestuario,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'licencias por jornadas' THEN s.id_solicitud END) AS permisos_licencias_jornadas,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'licencias por dias' THEN s.id_solicitud END) AS permisos_licencias_dias,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'modulo' THEN s.id_solicitud END) AS permisos_modulo,
        COUNT(DISTINCT CASE WHEN s.tipo_permiso = 'compensacion grupos especiales' THEN s.id_solicitud END) AS permisos_compensacion_grupos

    FROM fechas f
    LEFT JOIN {{ ref('fact_solicitudes') }} s
        ON f.fecha BETWEEN s.fecha_inicio AND COALESCE(s.fecha_fin, s.fecha_inicio)
       AND s.estado = 'confirmada'
    GROUP BY f.fecha
),

requerimientos_dia AS (
    SELECT
        fecha_inicio AS fecha,
        SUM(total_requerimientos) AS requerimientos_total,
        COUNT(DISTINCT CASE WHEN es_requerimiento THEN id_empleado END) AS bomberos_requeridos
    FROM {{ ref('fact_asignaciones_operativas') }}
    WHERE es_requerimiento = TRUE
    GROUP BY fecha_inicio
)

SELECT
    f.fecha,
    f.tipo_dia,

    COALESCE(p.permisos_activos_total, 0) AS permisos_activos_total,

    COALESCE(p.permisos_vacaciones, 0) AS permisos_vacaciones,
    COALESCE(p.permisos_asuntos_propios, 0) AS permisos_asuntos_propios,
    COALESCE(p.permisos_horas_sindicales, 0) AS permisos_horas_sindicales,
    COALESCE(p.permisos_salidas_personales, 0) AS permisos_salidas_personales,
    COALESCE(p.permisos_vestuario, 0) AS permisos_vestuario,
    COALESCE(p.permisos_licencias_jornadas, 0) AS permisos_licencias_jornadas,
    COALESCE(p.permisos_licencias_dias, 0) AS permisos_licencias_dias,
    COALESCE(p.permisos_modulo, 0) AS permisos_modulo,
    COALESCE(p.permisos_compensacion_grupos, 0) AS permisos_compensacion_grupos,

    COALESCE(r.requerimientos_total, 0) AS requerimientos_total,
    COALESCE(r.bomberos_requeridos, 0) AS bomberos_requeridos,

    ROUND(
        COALESCE(r.requerimientos_total, 0)
        / NULLIF(COALESCE(p.permisos_activos_total, 0), 0),
        3
    ) AS requerimientos_por_permiso_activo,

    ROUND(
        COALESCE(r.requerimientos_total, 0)
        / NULLIF(COALESCE(p.permisos_activos_total, 0), 0) * 100,
        2
    ) AS requerimientos_por_100_permisos_activos,

    CASE
        WHEN COALESCE(p.permisos_activos_total, 0) = 0 THEN '0 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 1 AND 2 THEN '1-2 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 3 AND 4 THEN '3-4 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 5 AND 6 THEN '5-6 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 7 AND 8 THEN '7-8 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 9 AND 10 THEN '9-10 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 11 AND 12 THEN '11-12 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 13 AND 15 THEN '13-15 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 16 AND 20 THEN '16-20 permisos'
        WHEN COALESCE(p.permisos_activos_total, 0) BETWEEN 21 AND 25 THEN '21-25 permisos'
        ELSE '26+ permisos'
    END AS tramo_permisos_activos,

    CASE
        WHEN COALESCE(r.requerimientos_total, 0) > 0 THEN TRUE
        ELSE FALSE
    END AS hubo_requerimientos

FROM fechas f
LEFT JOIN permisos_activos_dia p
    ON f.fecha = p.fecha
LEFT JOIN requerimientos_dia r
    ON f.fecha = r.fecha