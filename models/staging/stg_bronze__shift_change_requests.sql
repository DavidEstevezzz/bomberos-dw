WITH 

-- import CTE
src_shift_changes AS (
    SELECT *
    FROM {{ source('bronze', 'shift_change_requests') }}
),

-- renombrado, limpieza y tipado
shift_changes_renamed AS (
    SELECT
        ID::NUMBER(38,0) AS id_cambio
        , ID_EMPLEADO1::NUMBER(38,0) AS id_empleado_solicitante
        , ID_EMPLEADO2::NUMBER(38,0) AS id_empleado_receptor
        , ID_EMPLEADO3::NUMBER(38,0) AS id_empleado_aprobador
        , BRIGADA1::NUMBER(38,0) AS id_brigada_solicitante
        , BRIGADA2::NUMBER(38,0) AS id_brigada_receptor
        , FECHA::DATE AS fecha_cambio
        , FECHA2::DATE AS fecha_cambio_espejo
        , {{ limpiar_texto('ESTADO') }} AS estado
        , {{ limpiar_texto('TURNO') }} AS turno
        {{ campos_auditoria() }}
    FROM src_shift_changes
)

SELECT * FROM shift_changes_renamed