WITH 

-- import CTE
src_incidents AS (
    SELECT *
    FROM {{ source('bronze', 'incidents') }}
),

-- renombrado, limpieza y tipado
incidents_renamed AS (
    SELECT
        ID_INCIDENCIA::NUMBER(38,0) AS id_incidencia
        , ID_EMPLEADO::NUMBER(38,0) AS id_empleado_creador
        , {{ limpiar_texto('TIPO') }} AS tipo_incidencia
        , {{ limpiar_texto('ESTADO') }} AS estado
        , NULLIF({{ limpiar_texto('NIVEL') }}, '') AS nivel_gravedad
        , FECHA::DATE AS fecha_incidencia
        , ID_PARQUE::NUMBER(38,0) AS id_parque
        , NULLIF(TRIM(MATRICULA), '') AS matricula_vehiculo
        , TRY_TO_NUMBER(ID_EMPLEADO2)::NUMBER(38,0) AS id_empleado_referenciado
        , TRY_TO_NUMBER(EQUIPO)::NUMBER(38,0) AS id_equipo
        , TRY_TO_NUMBER(RESULTA_POR)::NUMBER(38,0) AS id_empleado_resolutor
        , COALESCE(LEIDO, FALSE)::BOOLEAN AS esta_leido
        , NULLIF(TRIM(NOMBRE_EQUIPO), '') AS nombre_equipo_comun
        {{ campos_auditoria() }}
    FROM src_incidents
),

-- campos derivados
incidents_with_metrics AS (
    SELECT
        *
        , CASE
            WHEN estado = 'resuelta' 
              AND fecha_creacion IS NOT NULL 
              AND fecha_actualizacion IS NOT NULL
              AND fecha_creacion >= '2020-01-01'
              AND fecha_actualizacion >= '2020-01-01'
              AND DATEDIFF('day', fecha_creacion, fecha_actualizacion) BETWEEN 0 AND 3650
            THEN DATEDIFF('day', fecha_creacion, fecha_actualizacion)
            ELSE NULL
          END AS dias_resolucion
    FROM incidents_renamed
)

SELECT * FROM incidents_with_metrics