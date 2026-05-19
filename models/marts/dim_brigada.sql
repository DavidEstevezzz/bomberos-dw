WITH 

-- import CTEs
stg_brigades AS (
    SELECT * FROM {{ ref('stg_bronze__brigades') }}
),

stg_parks AS (
    SELECT * FROM {{ ref('stg_bronze__parks') }}
),

-- denormalización: incluir nombre del parque en la dimensión
brigades_enriched AS (
    SELECT
        b.id_brigada
        , b.nombre_brigada
        , b.es_especial
        , b.es_brigada_servicio
        , b.id_parque
        , p.nombre_parque
    FROM stg_brigades b
    LEFT JOIN stg_parks p
        ON b.id_parque = p.id_parque
),

-- surrogate key
dim_brigada_real AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_brigada']) }} AS brigada_key
        , id_brigada
        , nombre_brigada
        , es_especial
        , es_brigada_servicio
        , id_parque
        , nombre_parque
    FROM brigades_enriched
),

-- Default Dimension Row para hechos sin brigada conocida
unknown_row AS (
    SELECT
        '-1'::VARCHAR AS brigada_key
        , -1::NUMBER(38,0) AS id_brigada
        , 'DESCONOCIDA'::VARCHAR AS nombre_brigada
        , FALSE::BOOLEAN AS es_especial
        , FALSE::BOOLEAN AS es_brigada_servicio
        , -1::NUMBER(38,0) AS id_parque
        , 'DESCONOCIDO'::VARCHAR AS nombre_parque
)

SELECT * FROM dim_brigada_real
UNION ALL
SELECT * FROM unknown_row