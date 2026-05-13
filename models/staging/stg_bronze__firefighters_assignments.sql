WITH 

src_assignments AS (
    SELECT *
    FROM {{ source('bronze', 'firefighters_assignments') }}
),

assignments_renamed AS (
    SELECT
        ID_ASIGNACION::NUMBER(38,0) AS id_asignacion
        , FECHA_INI::DATE AS fecha_inicio
        , ID_EMPLEADO::NUMBER(38,0) AS id_empleado
        , ID_BRIGADA_ORIGEN::NUMBER(38,0) AS id_brigada_origen
        , ID_BRIGADA_DESTINO::NUMBER(38,0) AS id_brigada_destino
        , {{ limpiar_texto('TURNO') }} AS turno
        , ID_REQUEST::NUMBER(38,0) AS id_solicitud
        , ID_CHANGE_REQUEST::NUMBER(38,0) AS id_cambio_guardia
        , COALESCE(REQUERIMIENTO, FALSE)::BOOLEAN AS es_requerimiento
        , {{ limpiar_texto('TIPO_ASIGNACION') }} AS tipo_asignacion
        , ID_TRANSFER::NUMBER(38,0) AS id_traslado
        {{ campos_auditoria() }}
    FROM src_assignments
)

SELECT *
FROM assignments_renamed
WHERE fecha_inicio >= '2020-01-01'