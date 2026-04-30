WITH 

-- import CTE
stg_salaries AS (
    SELECT * FROM {{ ref('stg_bronze__salaries') }}
),

-- surrogate key
dim_salario AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_salario']) }} AS salario_key
        , id_salario
        , tipo_salario
        , fecha_vigencia
        , precio_hora_diurna
        , precio_hora_nocturna
        , horas_diurnas_jornada
        , horas_nocturnas_jornada
    FROM stg_salaries
)

SELECT * FROM dim_salario