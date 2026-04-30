WITH 

-- import CTE
src_incidents AS (
    SELECT *
    FROM {{ source('bronze', 'incidents') }}
),

-- renombrado y limpieza
incidents_renamed AS (
    SELECT
        ID_INCIDENCIA AS id_incidencia
        , ID_EMPLEADO AS id_empleado_creador
        , {{ limpiar_texto('TIPO') }} AS tipo_incidencia
        , {{ limpiar_texto('ESTADO') }} AS estado
        , {{ limpiar_texto('NIVEL') }} AS nivel_gravedad
        , FECHA AS fecha_incidencia
        , ID_PARQUE AS id_parque
        , MATRICULA AS matricula_vehiculo
        , ID_EMPLEADO2 AS id_empleado_referenciado
        , EQUIPO AS id_equipo
        , RESULTA_POR AS id_empleado_resolutor
        , COALESCE(LEIDO, FALSE) AS esta_leido
        , TRIM(NOMBRE_EQUIPO) AS nombre_equipo_comun
        {{ campos_auditoria() }}
    FROM src_incidents
),

-- campos derivados
incidents_with_metrics AS (
    SELECT
        *
        , CASE
            WHEN estado = 'resuelta' AND fecha_creacion IS NOT NULL AND fecha_actualizacion IS NOT NULL
            THEN DATEDIFF('day', fecha_creacion, fecha_actualizacion)
            ELSE NULL
          END AS dias_resolucion
    FROM incidents_renamed
)

SELECT * FROM incidents_with_metrics