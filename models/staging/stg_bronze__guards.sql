WITH 

-- import CTE
src_guards AS (
    SELECT *
    FROM {{ source('bronze', 'guards') }}
),

-- renombrado y limpieza
guards_renamed AS (
    SELECT
        ID AS id_guardia
        , DATE AS fecha
        , ID_BRIGADA AS id_brigada
        , ID_PARQUE AS id_parque
        , ID_SALARIO AS id_salario
        , {{ limpiar_texto('TIPO') }} AS tipo_dia
        , TRIM(ESPECIALES) AS tipo_especial
        {{ campos_auditoria() }}
    FROM src_guards
)

SELECT * FROM guards_renamed