WITH 

-- import CTE
src_brigades AS (
    SELECT *
    FROM {{ source('bronze', 'brigades') }}
),

-- renombrado y limpieza
brigades_renamed AS (
    SELECT
        ID_BRIGADA AS id_brigada
        , ID_PARQUE AS id_parque
        , NULLIF(TRIM(NOMBRE), '') AS nombre_brigada
        , UPPER(NULLIF(TRIM(NOMBRE), '')) AS nombre_brigada_normalizado
        , COALESCE(ESPECIAL, FALSE) AS es_especial
    FROM src_brigades
),

-- campos derivados
brigades_with_flags AS (
    SELECT
        id_brigada
        , id_parque
        , nombre_brigada
        , es_especial
        , CASE
            WHEN nombre_brigada_normalizado IN ('A', 'B', 'C', 'D', 'E', 'F') THEN TRUE
            ELSE FALSE
          END AS es_brigada_servicio
    FROM brigades_renamed
)

SELECT * FROM brigades_with_flags