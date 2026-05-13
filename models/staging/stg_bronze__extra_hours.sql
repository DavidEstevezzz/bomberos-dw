WITH 

-- import CTE
src_extra_hours AS (
    SELECT *
    FROM {{ source('bronze', 'extra_hours') }}
),

-- renombrado, limpieza y tipado
extra_hours_renamed AS (
    SELECT
        ID::NUMBER(38,0) AS id_hora_extra
        , DATE::DATE AS fecha
        , ID_EMPLEADO::NUMBER(38,0) AS id_empleado
        , ID_SALARIO::NUMBER(38,0) AS id_salario
        , COALESCE(HORAS_DIURNAS, 0)::NUMBER(38,0) AS horas_diurnas
        , COALESCE(HORAS_NOCTURNAS, 0)::NUMBER(38,0) AS horas_nocturnas
        {{ campos_auditoria() }}
    FROM src_extra_hours
    WHERE DATE::DATE >= '2020-01-01'
),

-- campos derivados
extra_hours_with_totals AS (
    SELECT
        *
        , horas_diurnas + horas_nocturnas AS total_horas
    FROM extra_hours_renamed
)

SELECT * FROM extra_hours_with_totals