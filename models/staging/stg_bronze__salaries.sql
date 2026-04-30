WITH 

-- import CTE
src_salaries AS (
    SELECT *
    FROM {{ source('bronze', 'salaries') }}
),

-- renombrado
salaries_renamed AS (
    SELECT
        ID_SALARIO AS id_salario
        , FECHA_INI AS fecha_vigencia
        , TRIM(TIPO) AS tipo_salario
        , PRECIO_DIURNO AS precio_hora_diurna
        , PRECIO_NOCTURNO AS precio_hora_nocturna
        , COALESCE(HORAS_DIURNAS, 0) AS horas_diurnas_jornada
        , COALESCE(HORAS_NOCTURNAS, 0) AS horas_nocturnas_jornada
    FROM src_salaries
)

SELECT * FROM salaries_renamed