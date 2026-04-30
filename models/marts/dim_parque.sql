WITH 

-- import CTE
stg_parks AS (
    SELECT * FROM {{ ref('stg_bronze__parks') }}
),

-- surrogate key + atributos
dim_parque AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_parque']) }} AS parque_key
        , id_parque
        , nombre_parque
        , ubicacion
    FROM stg_parks
)

SELECT * FROM dim_parque