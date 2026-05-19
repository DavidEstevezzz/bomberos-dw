{{
    config(
        materialized='table'
    )
}}

WITH

-- Time spine: una fila por día garantizada, sin huecos
spine AS (
    SELECT date_day AS fecha
    FROM {{ ref('dim_time') }}
),

-- Guardias del sistema operativo: aporta tipo_dia cuando existe dato real
stg_guards AS (
    SELECT *
    FROM {{ ref('stg_bronze__guards') }}
),

-- Si hay varias guardias por fecha, nos quedamos con una fila representativa
guards_per_date AS (
    SELECT
        fecha
        , tipo_dia
        , ROW_NUMBER() OVER (PARTITION BY fecha ORDER BY id_guardia) AS rn
    FROM stg_guards
),

guards_unique AS (
    SELECT
        fecha
        , tipo_dia AS tipo_dia_guardia
    FROM guards_per_date
    WHERE rn = 1
),

-- Enriquecimiento calendario + tipo de día operativo
enriched AS (
    SELECT
        s.fecha

        -- atributos calendario
        , YEAR(s.fecha) AS anio
        , QUARTER(s.fecha) AS trimestre
        , MONTH(s.fecha) AS mes
        , MONTHNAME(s.fecha) AS mes_nombre
        , WEEKOFYEAR(s.fecha) AS semana_anio
        , DAY(s.fecha) AS dia
        , DAYOFWEEKISO(s.fecha) AS dia_semana_num
        , DAYNAME(s.fecha) AS dia_semana_nombre

        -- tipo de día operativo: viene exclusivamente de guards
        , g.tipo_dia_guardia AS tipo_dia

        -- flags derivados del calendario
        , CASE
            WHEN DAYOFWEEKISO(s.fecha) IN (6, 7) THEN TRUE
            ELSE FALSE
          END AS es_fin_de_semana

        -- flags derivados del tipo_dia operativo
        , CASE WHEN g.tipo_dia_guardia = 'festivo' THEN TRUE ELSE FALSE END AS es_festivo
        , CASE WHEN g.tipo_dia_guardia = 'prefestivo' THEN TRUE ELSE FALSE END AS es_prefestivo
        , CASE WHEN g.tipo_dia_guardia = 'festivo víspera' THEN TRUE ELSE FALSE END AS es_festivo_vispera
        , CASE WHEN g.tipo_dia_guardia = 'laborable' THEN TRUE ELSE FALSE END AS es_laborable

        -- flag de calidad: TRUE si no tenemos dato operativo de guardia
        , CASE
            WHEN g.tipo_dia_guardia IS NULL THEN TRUE
            ELSE FALSE
          END AS sin_datos_guardia

    FROM spine s
    LEFT JOIN guards_unique g
        ON s.fecha = g.fecha
),

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
        , sin_datos_guardia
        , es_festivo
        , es_prefestivo
        , es_festivo_vispera
        , es_laborable
        , es_fin_de_semana
    FROM enriched
)

SELECT * FROM final