WITH 

-- import CTE
stg_users AS (
    SELECT DISTINCT
        puesto
        , categoria_puesto
    FROM {{ ref('stg_bronze__users') }}
    WHERE puesto IS NOT NULL
),

-- atributos derivados
puestos_enriched AS (
    SELECT
        puesto AS nombre_puesto
        , categoria_puesto
        , CASE
            WHEN categoria_puesto = 'Tropa' THEN TRUE
            ELSE FALSE
          END AS es_tropa
        , CASE
            WHEN categoria_puesto = 'Mando' THEN TRUE
            ELSE FALSE
          END AS es_mando
    FROM stg_users
),

-- surrogate key
dim_puesto AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['nombre_puesto']) }} AS puesto_key
        , nombre_puesto
        , categoria_puesto
        , es_tropa
        , es_mando
    FROM puestos_enriched
)

SELECT * FROM dim_puesto