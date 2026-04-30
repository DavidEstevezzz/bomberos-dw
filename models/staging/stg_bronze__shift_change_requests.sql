WITH 

-- import CTE
src_shift_changes AS (
    SELECT *
    FROM {{ source('bronze', 'shift_change_requests') }}
),

-- renombrado y limpieza
shift_changes_renamed AS (
    SELECT
        ID AS id_cambio
        , ID_EMPLEADO1 AS id_empleado_solicitante
        , ID_EMPLEADO2 AS id_empleado_receptor
        , ID_EMPLEADO3 AS id_empleado_aprobador
        , BRIGADA1 AS id_brigada_solicitante
        , BRIGADA2 AS id_brigada_receptor
        , FECHA AS fecha_cambio
        , FECHA2 AS fecha_cambio_espejo
        , {{ limpiar_texto('ESTADO') }} AS estado
        , {{ limpiar_texto('TURNO') }} AS turno
        {{ campos_auditoria() }}
    FROM src_shift_changes
)

SELECT * FROM shift_changes_renamed