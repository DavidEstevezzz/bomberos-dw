WITH 

src_users AS (
    SELECT *
    FROM {{ source('bronze', 'users') }}
),

users_renamed AS (
    SELECT
        ID_EMPLEADO AS id_empleado
        , NOMBRE AS nombre_token
        , {{ limpiar_texto('TYPE') }} AS tipo_usuario
        , TRIM(PUESTO) AS puesto
        , {{ limpiar_texto('PUESTO') }} AS puesto_normalizado
        , COALESCE(AP, 0) AS dias_asuntos_propios
        , COALESCE(VACACIONES, 0) AS dias_vacaciones
        , COALESCE(MODULO, 0) AS dias_modulo
        , COALESCE(SP, 0) AS salidas_personales
        , COALESCE(COMPENSACION_GRUPOS, 0) AS dias_compensacion_grupos
        , COALESCE(HORAS_SINDICALES, 0) AS horas_sindicales
        , COALESCE(MANDO_ESPECIAL, FALSE) AS es_mando_especial
        {{ campos_auditoria() }}
    FROM src_users
),

users_with_category AS (
    SELECT
        id_empleado
        , nombre_token
        , tipo_usuario
        , puesto
        , dias_asuntos_propios
        , dias_vacaciones
        , dias_modulo
        , salidas_personales
        , dias_compensacion_grupos
        , horas_sindicales
        , es_mando_especial
        , fecha_creacion
        , fecha_actualizacion
        , CASE
            WHEN puesto_normalizado IN ('conductor', 'operador', 'bombero') THEN 'Tropa'
            WHEN puesto_normalizado IN ('subinspector', 'oficial') THEN 'Mando'
            WHEN puesto_normalizado IS NULL THEN 'Administrativo'
            ELSE 'Desconocido'
          END AS categoria_puesto
    FROM users_renamed
)

SELECT * FROM users_with_category