WITH 

-- import CTE
src_equipos AS (
    SELECT *
    FROM {{ source('bronze', 'equipos_personales') }}
),

-- renombrado, limpieza y tipado
equipos_renamed AS (
    SELECT
        ID::NUMBER(38,0) AS id_equipo
        , NULLIF(TRIM(NOMBRE), '') AS nombre_equipo
        , NULLIF({{ limpiar_texto('CATEGORIA') }}, '') AS categoria_equipo
        , COALESCE(DISPONIBLE, FALSE)::BOOLEAN AS esta_disponible
        , TRY_TO_NUMBER(PARQUE)::NUMBER(38,0) AS id_parque
        {{ campos_auditoria() }}
    FROM src_equipos
)

SELECT * FROM equipos_renamed