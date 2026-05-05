WITH 

snp_empleado AS (
    SELECT * FROM {{ ref('snp_empleado') }}
),

dim_empleado_real AS (
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
),

-- Default Dimension Row para hechos sin empleado conocido
unknown_row AS (
    SELECT
        '-1'::VARCHAR AS empleado_key
        , -1::NUMBER(38,0) AS id_empleado
        , 'DESCONOCIDO'::VARCHAR AS nombre_token
        , 'desconocido'::VARCHAR AS tipo_usuario
        , 'desconocido'::VARCHAR AS puesto
        , 'desconocido'::VARCHAR AS categoria_puesto
        , FALSE AS es_mando_especial
        , '1900-01-01'::TIMESTAMP_NTZ AS fecha_inicio_validez
        , NULL::TIMESTAMP_NTZ AS fecha_fin_validez
        , TRUE AS es_version_actual
        , FALSE AS es_eliminado
)

SELECT * FROM dim_empleado_real
UNION ALL
SELECT * FROM unknown_row