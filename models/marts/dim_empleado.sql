WITH 

-- import CTE: leer del snapshot SCD2
snp_empleado AS (
    SELECT * FROM {{ ref('snp_empleado') }}
),

-- surrogate key + selección de campos
dim_empleado AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_empleado', 'dbt_valid_from']) }} AS empleado_key
        , id_empleado
        , nombre_token
        , tipo_usuario
        , puesto
        , categoria_puesto
        , es_mando_especial
        , dbt_valid_from AS fecha_inicio_validez
        , dbt_valid_to AS fecha_fin_validez
        , CASE
            WHEN dbt_valid_to IS NULL AND COALESCE(dbt_is_deleted, FALSE) = FALSE THEN TRUE
            ELSE FALSE
          END AS es_version_actual
        , COALESCE(dbt_is_deleted, FALSE) AS es_eliminado
    FROM snp_empleado
)

SELECT * FROM dim_empleado