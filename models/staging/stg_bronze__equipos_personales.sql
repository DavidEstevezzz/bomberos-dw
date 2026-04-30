WITH 

-- import CTE
src_equipos AS (
    SELECT *
    FROM {{ source('bronze', 'equipos_personales') }}
),

-- renombrado
equipos_renamed AS (
    SELECT
        ID AS id_equipo
        , TRIM(NOMBRE) AS nombre_equipo
        , {{ limpiar_texto('CATEGORIA') }} AS categoria_equipo
        , COALESCE(DISPONIBLE, FALSE) AS esta_disponible
        , PARQUE AS id_parque
        {{ campos_auditoria() }}
    FROM src_equipos
)

SELECT * FROM equipos_renamed