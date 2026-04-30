WITH 

-- import CTEs
stg_vehicles AS (
    SELECT * FROM {{ ref('stg_bronze__vehicles') }}
),

stg_parks AS (
    SELECT * FROM {{ ref('stg_bronze__parks') }}
),

-- denormalización: incluir nombre del parque
vehicles_enriched AS (
    SELECT
        v.matricula_token
        , v.nombre_vehiculo
        , v.tipo_vehiculo
        , v.anio_vehiculo
        , v.id_parque
        , p.nombre_parque
    FROM stg_vehicles v
    LEFT JOIN stg_parks p
        ON v.id_parque = p.id_parque
),

-- surrogate key
dim_vehiculo AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['matricula_token']) }} AS vehiculo_key
        , matricula_token
        , nombre_vehiculo
        , tipo_vehiculo
        , anio_vehiculo
        , id_parque
        , nombre_parque
    FROM vehicles_enriched
)

SELECT * FROM dim_vehiculo