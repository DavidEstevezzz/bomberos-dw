WITH 

-- import CTE
src_extra_hours AS (
    SELECT *
    FROM {{ source('bronze', 'extra_hours') }}
),

-- renombrado y limpieza
extra_hours_renamed AS (
    SELECT
        ID AS id_hora_extra
        , DATE AS fecha
        , ID_EMPLEADO AS id_empleado
        , ID_SALARIO AS id_salario
        , COALESCE(HORAS_DIURNAS, 0) AS horas_diurnas
        , COALESCE(HORAS_NOCTURNAS, 0) AS horas_nocturnas
        {{ campos_auditoria() }}
    FROM src_extra_hours
),

-- campos derivados
extra_hours_with_totals AS (
    SELECT
        *
        , horas_diurnas + horas_nocturnas AS total_horas
    FROM extra_hours_renamed
)

SELECT * FROM extra_hours_with_totals