WITH 

-- import CTE
src_parks AS (
    SELECT *
    FROM {{ source('bronze', 'parks') }}
),

-- renombrado
parks_renamed AS (
    SELECT
        ID_PARQUE AS id_parque
        , TRIM(NOMBRE) AS nombre_parque
        , TRIM(UBICACION) AS ubicacion
    FROM src_parks
)

SELECT * FROM parks_renamed