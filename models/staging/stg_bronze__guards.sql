WITH 

-- import CTE
src_guards AS (
    SELECT *
    FROM {{ source('bronze', 'guards') }}
),

-- renombrado, limpieza y tipado
guards_renamed AS (
    SELECT
        ID::NUMBER(38,0) AS id_guardia
        , DATE::DATE AS fecha
        , ID_BRIGADA::NUMBER(38,0) AS id_brigada
        , ID_PARQUE::NUMBER(38,0) AS id_parque
        , ID_SALARIO::NUMBER(38,0) AS id_salario
        , {{ limpiar_texto('TIPO') }} AS tipo_dia
        , NULLIF(TRIM(ESPECIALES), '') AS tipo_especial
        {{ campos_auditoria() }}
    FROM src_guards
)

SELECT * FROM guards_renamed