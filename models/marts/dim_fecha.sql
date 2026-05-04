WITH 

-- import CTE: generar rango completo de fechas
date_spine AS (
    SELECT
        DATEADD('day', seq4(), '2020-01-01'::DATE) AS fecha
    FROM TABLE(GENERATOR(ROWCOUNT => 3000))
),

-- filtrar solo hasta la fecha máxima de datos
date_range AS (
    SELECT fecha
    FROM date_spine
    WHERE fecha <= CURRENT_DATE() + 365
),

-- tipo de día desde guardias (puede no existir para todas las fechas)
stg_guards AS (
    SELECT
        fecha
        , MIN(tipo_dia) AS tipo_dia
    FROM {{ ref('stg_bronze__guards') }}
    WHERE fecha IS NOT NULL
    GROUP BY fecha
),

-- unir fechas completas con tipo de día
fechas_enriched AS (
    SELECT
        d.fecha
        , g.tipo_dia
        , EXTRACT(YEAR FROM d.fecha) AS anio
        , EXTRACT(MONTH FROM d.fecha) AS mes
        , EXTRACT(DAY FROM d.fecha) AS dia
        , EXTRACT(QUARTER FROM d.fecha) AS trimestre
        , DAYOFWEEK(d.fecha) AS dia_semana_num
        , DAYNAME(d.fecha) AS dia_semana_nombre
        , MONTHNAME(d.fecha) AS mes_nombre
        , WEEKOFYEAR(d.fecha) AS semana_anio
        , CASE
            WHEN g.tipo_dia IN ('festivo', 'festivo víspera') THEN TRUE
            ELSE FALSE
          END AS es_festivo
        , CASE
            WHEN g.tipo_dia = 'prefestivo' THEN TRUE
            ELSE FALSE
          END AS es_prefestivo
        , CASE
            WHEN g.tipo_dia = 'laborable' THEN TRUE
            ELSE FALSE
          END AS es_laborable
        , CASE
            WHEN DAYOFWEEK(d.fecha) IN (0, 6) THEN TRUE
            ELSE FALSE
          END AS es_fin_de_semana
        , CASE
            WHEN g.tipo_dia IS NULL THEN TRUE
            ELSE FALSE
          END AS sin_datos_guardia
    FROM date_range d
    LEFT JOIN stg_guards g
        ON d.fecha = g.fecha
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
        , sin_datos_guardia
    FROM fechas_enriched
)

SELECT * FROM dim_fecha