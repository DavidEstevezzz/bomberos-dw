WITH 

-- import CTE
src_parks AS (
    SELECT *
    FROM {{ source('bronze', 'parks') }}
),

-- renombrado y limpieza
parks_renamed AS (
    SELECT
        ID_PARQUE AS id_parque
        , NULLIF(TRIM(NOMBRE), '') AS nombre_parque
        , NULLIF(TRIM(UBICACION), '') AS ubicacion
    FROM src_parks
)

SELECT * FROM parks_renamed