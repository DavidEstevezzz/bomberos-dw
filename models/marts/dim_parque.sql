WITH 

-- import CTE
stg_parks AS (
    SELECT * FROM {{ ref('stg_bronze__parks') }}
),

-- surrogate key + atributos
dim_parque_real AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_parque']) }} AS parque_key
        , id_parque
        , nombre_parque
        , ubicacion
    FROM stg_parks
),

-- Default Dimension Row para hechos sin parque conocido
unknown_row AS (
    SELECT
        '-1'::VARCHAR AS parque_key
        , -1::NUMBER(38,0) AS id_parque
        , 'DESCONOCIDO'::VARCHAR AS nombre_parque
        , 'DESCONOCIDO'::VARCHAR AS ubicacion
)

SELECT * FROM dim_parque_real
UNION ALL
SELECT * FROM unknown_row