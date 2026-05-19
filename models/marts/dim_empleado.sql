WITH 

snp_empleado AS (
    SELECT * FROM {{ ref('snp_empleado') }}
),

dim_empleado_real AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_empleado', 'dbt_valid_from']) }}::VARCHAR AS empleado_key
        , id_empleado::NUMBER(38,0) AS id_empleado
        , nombre_token::VARCHAR AS nombre_token
        , tipo_usuario::VARCHAR AS tipo_usuario
        , puesto::VARCHAR AS puesto
        , categoria_puesto::VARCHAR AS categoria_puesto
        , es_mando_especial::BOOLEAN AS es_mando_especial
        , dbt_valid_from::TIMESTAMP_NTZ AS fecha_inicio_validez
        , dbt_valid_to::TIMESTAMP_NTZ AS fecha_fin_validez
        , CASE
            WHEN dbt_valid_to IS NULL
              AND COALESCE(dbt_is_deleted, FALSE) = FALSE
            THEN TRUE
            ELSE FALSE
          END::BOOLEAN AS es_version_actual
        , COALESCE(dbt_is_deleted, FALSE)::BOOLEAN AS es_eliminado
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
        , 'Desconocido'::VARCHAR AS categoria_puesto
        , CAST(FALSE AS BOOLEAN) AS es_mando_especial
        , '1900-01-01'::TIMESTAMP_NTZ AS fecha_inicio_validez
        , NULL::TIMESTAMP_NTZ AS fecha_fin_validez
        , CAST(TRUE AS BOOLEAN) AS es_version_actual
        , CAST(FALSE AS BOOLEAN) AS es_eliminado
)

SELECT * FROM dim_empleado_real
UNION ALL
SELECT * FROM unknown_row