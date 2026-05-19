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
dim_vehiculo_real AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['matricula_token']) }} AS vehiculo_key
        , matricula_token
        , nombre_vehiculo
        , tipo_vehiculo
        , anio_vehiculo
        , id_parque
        , nombre_parque
    FROM vehicles_enriched
),

-- Default Dimension Row para hechos sin vehículo conocido
unknown_row AS (
    SELECT
        '-1'::VARCHAR AS vehiculo_key
        , 'DESCONOCIDO'::VARCHAR AS matricula_token
        , 'DESCONOCIDO'::VARCHAR AS nombre_vehiculo
        , 'desconocido'::VARCHAR AS tipo_vehiculo
        , NULL::NUMBER(38,0) AS anio_vehiculo
        , -1::NUMBER(38,0) AS id_parque
        , 'DESCONOCIDO'::VARCHAR AS nombre_parque
)

SELECT * FROM dim_vehiculo_real
UNION ALL
SELECT * FROM unknown_row