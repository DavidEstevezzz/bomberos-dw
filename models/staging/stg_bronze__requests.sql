WITH 

-- import CTE
src_requests AS (
    SELECT *
    FROM {{ source('bronze', 'requests') }}
),

-- renombrado, limpieza y tipado
requests_renamed AS (
    SELECT
        ID::NUMBER(38,0) AS id_solicitud
        , ID_EMPLEADO::NUMBER(38,0) AS id_empleado
        , ID_EMPLEADO2::NUMBER(38,0) AS id_empleado_gestor
        , {{ limpiar_texto('TIPO') }} AS tipo_permiso
        , FECHA_INI::DATE AS fecha_inicio
        , FECHA_FIN::DATE AS fecha_fin
        , COALESCE(HORAS, 0)::NUMBER(38,0) AS horas_solicitadas
        , {{ limpiar_texto('TURNO') }} AS turno
        , {{ limpiar_texto('ESTADO') }} AS estado
        {{ campos_auditoria() }}
    FROM src_requests
    WHERE FECHA_INI IS NULL OR FECHA_INI::DATE >= '2020-01-01'
)

SELECT * FROM requests_renamed