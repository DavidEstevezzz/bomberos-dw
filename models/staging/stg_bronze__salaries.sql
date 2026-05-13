WITH 

-- import CTE
src_salaries AS (
    SELECT *
    FROM {{ source('bronze', 'salaries') }}
),

-- renombrado y tipado
salaries_renamed AS (
    SELECT
        ID_SALARIO::NUMBER(38,0) AS id_salario
        , FECHA_INI::DATE AS fecha_vigencia
        , NULLIF(TRIM(TIPO), '') AS tipo_salario
        , PRECIO_DIURNO::NUMBER(10,2) AS precio_hora_diurna
        , PRECIO_NOCTURNO::NUMBER(10,2) AS precio_hora_nocturna
        , COALESCE(HORAS_DIURNAS, 0)::NUMBER(38,0) AS horas_diurnas_jornada
        , COALESCE(HORAS_NOCTURNAS, 0)::NUMBER(38,0) AS horas_nocturnas_jornada
    FROM src_salaries
)

SELECT * FROM salaries_renamed