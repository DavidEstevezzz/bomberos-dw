WITH 

-- import CTE
src_users AS (
    SELECT *
    FROM {{ source('bronze', 'users') }}
),

-- renombrado y limpieza
users_renamed AS (
    SELECT
        ID_EMPLEADO AS id_empleado
        , NOMBRE AS nombre_token
        , {{ limpiar_texto('TYPE') }} AS tipo_usuario
        , TRIM(PUESTO) AS puesto
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

-- campos derivados
users_with_category AS (
    SELECT
        *
        , CASE
            WHEN puesto IN ('Conductor', 'Operador', 'Bombero') THEN 'Tropa'
            WHEN puesto IN ('Subinspector', 'Oficial') THEN 'Mando'
            WHEN puesto IS NULL THEN 'Administrativo'
            ELSE 'Desconocido'
          END AS categoria_puesto
    FROM users_renamed
)

SELECT * FROM users_with_category