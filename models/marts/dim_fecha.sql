WITH 

-- import CTE: extraer fechas únicas de guardias
stg_guards AS (
    SELECT
        fecha
        , MIN(tipo_dia) AS tipo_dia
    FROM {{ ref('stg_bronze__guards') }}
    WHERE fecha IS NOT NULL
    GROUP BY fecha
),

-- atributos de calendario derivados
fechas_enriched AS (
    SELECT
        fecha
        , tipo_dia
        , EXTRACT(YEAR FROM fecha) AS anio
        , EXTRACT(MONTH FROM fecha) AS mes
        , EXTRACT(DAY FROM fecha) AS dia
        , EXTRACT(QUARTER FROM fecha) AS trimestre
        , DAYOFWEEK(fecha) AS dia_semana_num
        , DAYNAME(fecha) AS dia_semana_nombre
        , MONTHNAME(fecha) AS mes_nombre
        , WEEKOFYEAR(fecha) AS semana_anio
        , CASE
            WHEN tipo_dia IN ('festivo', 'festivo víspera') THEN TRUE
            ELSE FALSE
          END AS es_festivo
        , CASE
            WHEN tipo_dia = 'prefestivo' THEN TRUE
            ELSE FALSE
          END AS es_prefestivo
        , CASE
            WHEN tipo_dia = 'laborable' THEN TRUE
            ELSE FALSE
          END AS es_laborable
        , CASE
            WHEN DAYOFWEEK(fecha) IN (0, 6) THEN TRUE
            ELSE FALSE
          END AS es_fin_de_semana
    FROM stg_guards
),

-- surrogate key
dim_fecha AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['fecha']) }} AS fecha_key
        , fecha
        , anio
        , trimestre
        , mes
        , mes_nombre
        , semana_anio
        , dia
        , dia_semana_num
        , dia_semana_nombre
        , tipo_dia
        , es_festivo
        , es_prefestivo
        , es_laborable
        , es_fin_de_semana
    FROM fechas_enriched
)

SELECT * FROM dim_fecha