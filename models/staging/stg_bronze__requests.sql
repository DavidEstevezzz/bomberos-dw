WITH 

-- import CTE
src_requests AS (
    SELECT *
    FROM {{ source('bronze', 'requests') }}
),

-- renombrado y limpieza
requests_renamed AS (
    SELECT
        ID AS id_solicitud
        , ID_EMPLEADO AS id_empleado
        , ID_EMPLEADO2 AS id_empleado_gestor
        , {{ limpiar_texto('TIPO') }} AS tipo_permiso
        , FECHA_INI AS fecha_inicio
        , FECHA_FIN AS fecha_fin
        , COALESCE(HORAS, 0) AS horas_solicitadas
        , {{ limpiar_texto('TURNO') }} AS turno
        , {{ limpiar_texto('ESTADO') }} AS estado
        , GUARDIAS_VACACIONES AS guardias_vacaciones_json
        , GUARDIAS_SELECCIONADAS AS guardias_seleccionadas_json
        {{ campos_auditoria() }}
    FROM src_requests
)

SELECT * FROM requests_renamed