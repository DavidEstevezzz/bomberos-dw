{{
    config(
        materialized='table'
    )
}}

WITH

-- partimos de la time spine: una fila por día garantizada, sin huecos
spine AS (
    SELECT date_day AS fecha
    FROM {{ ref('dim_time') }}
),

-- guardias del sistema operativo: aporta tipo_dia cuando hay guardia ese día
stg_guards AS (
    SELECT * FROM {{ ref('stg_bronze__guards') }}
),

guards_per_date AS (
    SELECT
        fecha
        , tipo_dia
        , ROW_NUMBER() OVER (PARTITION BY fecha ORDER BY id_guardia) AS rn
    FROM stg_guards
),

guards_unique AS (
    SELECT fecha, tipo_dia AS tipo_dia_guardia
    FROM guards_per_date
    WHERE rn = 1
),

-- enriquecer la spine con atributos de calendario y flags derivados
enriched AS (
    SELECT
        s.fecha
        -- atributos puramente derivables del calendario (siempre correctos)
        , YEAR(s.fecha) AS anio
        , QUARTER(s.fecha) AS trimestre
        , MONTH(s.fecha) AS mes
        , MONTHNAME(s.fecha) AS mes_nombre
        , WEEKOFYEAR(s.fecha) AS semana_anio
        , DAY(s.fecha) AS dia
        , DAYOFWEEK(s.fecha) AS dia_semana_num
        , DAYNAME(s.fecha) AS dia_semana_nombre
        , CASE
            WHEN DAYOFWEEK(s.fecha) IN (0, 6) THEN TRUE
            ELSE FALSE
          END AS es_fin_de_semana
        -- tipo_dia: prioridad guardias → fallback derivado
        , COALESCE(
            LOWER(g.tipo_dia_guardia),
            CASE
                WHEN DAYOFWEEK(s.fecha) IN (0, 6) THEN 'fin de semana'
                ELSE 'laborable'
            END
          ) AS tipo_dia
        -- flags binarios derivados de tipo_dia
        , CASE
            WHEN LOWER(g.tipo_dia_guardia) IN ('festivo') THEN TRUE
            ELSE FALSE
          END AS es_festivo
        , CASE
            WHEN LOWER(g.tipo_dia_guardia) IN ('prefestivo', 'festivo víspera') THEN TRUE
            ELSE FALSE
          END AS es_prefestivo
        , CASE
            WHEN g.tipo_dia_guardia IS NULL AND DAYOFWEEK(s.fecha) NOT IN (0, 6) THEN TRUE
            WHEN LOWER(g.tipo_dia_guardia) = 'laborable' THEN TRUE
            ELSE FALSE
          END AS es_laborable
        -- flag de calidad: marca cuando no tenemos info de guardia para esa fecha
        , CASE
            WHEN g.tipo_dia_guardia IS NULL THEN TRUE
            ELSE FALSE
          END AS sin_datos_guardia
    FROM spine s
    LEFT JOIN guards_unique g
        ON s.fecha = g.fecha
),

-- surrogate key final
final AS (
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
    FROM enriched
)

SELECT * FROM final