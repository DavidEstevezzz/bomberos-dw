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
        , DAYOFWEEK(s.fecha) AS dia_semana_num
        , DAYNAME(s.fecha) AS dia_semana_nombre

        -- tipo de día operativo: viene exclusivamente de guards
        , g.tipo_dia_guardia AS tipo_dia

        -- flags derivados del calendario
        , CASE
            WHEN DAYOFWEEK(s.fecha) IN (0, 6) THEN TRUE
            ELSE FALSE
          END AS es_fin_de_semana

        -- flags derivados del tipo_dia operativo
        , CASE WHEN g.tipo_dia_guardia = 'festivo' THEN TRUE ELSE FALSE END AS es_festivo
        , CASE WHEN g.tipo_dia_guardia = 'prefestivo' THEN TRUE ELSE FALSE END AS es_prefestivo
        , CASE WHEN g.tipo_dia_guardia = 'festivo víspera' THEN TRUE ELSE FALSE END AS es_festivo_vispera
        , CASE WHEN g.tipo_dia_guardia = 'laborable' THEN TRUE ELSE FALSE END AS es_laborable

        -- flag de calidad
        , CASE
            WHEN g.tipo_dia_guardia IS NULL THEN TRUE
            ELSE FALSE
          END AS sin_datos_guardia

    FROM spine s
    LEFT JOIN guards_unique g
        ON s.fecha = g.fecha
)