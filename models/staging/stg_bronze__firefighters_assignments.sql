WITH 

-- import CTE
src_assignments AS (
    SELECT *
    FROM {{ source('bronze', 'firefighters_assignments') }}
),

-- renombrado y limpieza
assignments_renamed AS (
    SELECT
        ID_ASIGNACION AS id_asignacion
        , FECHA_INI AS fecha_inicio
        , ID_EMPLEADO AS id_empleado
        , ID_BRIGADA_ORIGEN AS id_brigada_origen
        , ID_BRIGADA_DESTINO AS id_brigada_destino
        , {{ limpiar_texto('TURNO') }} AS turno
        , ID_REQUEST AS id_solicitud
        , ID_CHANGE_REQUEST AS id_cambio_guardia
        , COALESCE(REQUERIMIENTO, FALSE) AS es_requerimiento
        , {{ limpiar_texto('TIPO_ASIGNACION') }} AS tipo_asignacion
        , ID_TRANSFER AS id_traslado
        {{ campos_auditoria() }}
    FROM src_assignments
)

SELECT * FROM assignments_renamed