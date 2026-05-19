WITH 

-- import CTEs
stg_equipos AS (
    SELECT * FROM {{ ref('stg_bronze__equipos_personales') }}
),

stg_parks AS (
    SELECT * FROM {{ ref('stg_bronze__parks') }}
),

-- denormalización: incluir nombre del parque
equipos_enriched AS (
    SELECT
        e.id_equipo
        , e.nombre_equipo
        , e.categoria_equipo
        , e.esta_disponible
        , e.id_parque
        , p.nombre_parque
    FROM stg_equipos e
    LEFT JOIN stg_parks p
        ON e.id_parque = p.id_parque
),

-- surrogate key
dim_equipo_real AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_equipo']) }} AS equipo_key
        , id_equipo
        , nombre_equipo
        , categoria_equipo
        , esta_disponible
        , id_parque
        , nombre_parque
    FROM equipos_enriched
),

-- Default Dimension Row para hechos sin equipo conocido
unknown_row AS (
    SELECT
        '-1'::VARCHAR AS equipo_key
        , -1::NUMBER(38,0) AS id_equipo
        , 'DESCONOCIDO'::VARCHAR AS nombre_equipo
        , 'desconocido'::VARCHAR AS categoria_equipo
        , FALSE::BOOLEAN AS esta_disponible
        , -1::NUMBER(38,0) AS id_parque
        , 'DESCONOCIDO'::VARCHAR AS nombre_parque
)

SELECT * FROM dim_equipo_real
UNION ALL
SELECT * FROM unknown_row