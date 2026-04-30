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
        , TRIM(NOMBRE) AS nombre_brigada
        , COALESCE(ESPECIAL, FALSE) AS es_especial
    FROM src_brigades
),

-- campos derivados
brigades_with_flags AS (
    SELECT
        *
        , CASE
            WHEN nombre_brigada IN ('A', 'B', 'C', 'D', 'E', 'F') THEN TRUE
            ELSE FALSE
          END AS es_brigada_servicio
    FROM brigades_renamed
)

SELECT * FROM brigades_with_flags