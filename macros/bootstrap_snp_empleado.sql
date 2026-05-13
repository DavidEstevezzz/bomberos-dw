{% macro bootstrap_snp_empleado(force=false) %}

{# 
  Bootstrap del snapshot SCD2 de empleados.
  
  Inicializa snp_empleado con una versión por empleado fechada en 
  '2024-01-01' (anterior al primer hecho histórico: 2024-02-13).
  
  Necesario porque dbt snapshot, en su primera ejecución, fecharía 
  dbt_valid_from = NOW() y dejaría todos los hechos históricos huérfanos.
  
  Protección: si la tabla ya existe con datos, falla salvo force=true.
  Esto previene la destrucción accidental del historial SCD2 acumulado.
  
  Uso normal (primera vez):
    dbt run-operation bootstrap_snp_empleado
  
  Uso forzado (re-bootstrap completo, destructivo):
    dbt run-operation bootstrap_snp_empleado --args '{force: true}'
#}

{% set bootstrap_date = '2024-01-01 00:00:00' %}
{% set snapshot_schema = target.schema %}
{% set snapshot_table = target.database ~ '.' ~ snapshot_schema ~ '.snp_empleado' %}

{# Check defensivo: ¿ya existe la tabla con datos? #}
{% set check_sql %}
    SELECT COUNT(*) AS n
    FROM {{ snapshot_table }}
{% endset %}

{% set existing_rows = 0 %}
{% set check_result = run_query(check_sql) %}
{% if check_result and check_result.rows | length > 0 %}
    {% set existing_rows = check_result.rows[0][0] %}
{% endif %}

{% if existing_rows > 0 and not force %}
    {% do exceptions.raise_compiler_error(
        "snp_empleado ya contiene " ~ existing_rows ~ " filas. "
        ~ "Para re-bootstrappear (DESTRUCTIVO): "
        ~ "dbt run-operation bootstrap_snp_empleado --args '{force: true}'"
    ) %}
{% endif %}

{% set sql %}
CREATE OR REPLACE TRANSIENT TABLE {{ snapshot_table }} AS
SELECT
    id_empleado,
    nombre_token,
    tipo_usuario,
    puesto,
    dias_asuntos_propios,
    dias_vacaciones,
    dias_modulo,
    salidas_personales,
    dias_compensacion_grupos,
    horas_sindicales,
    es_mando_especial,
    fecha_creacion,
    fecha_actualizacion,
    categoria_puesto,
    -- columnas que dbt snapshot añade automáticamente
    MD5(
        CAST(id_empleado AS VARCHAR) 
        || '|' 
        || '{{ bootstrap_date }}'
    ) AS dbt_scd_id,
    '{{ bootstrap_date }}'::TIMESTAMP_NTZ AS dbt_updated_at,
    '{{ bootstrap_date }}'::TIMESTAMP_NTZ AS dbt_valid_from,
    NULL::TIMESTAMP_NTZ AS dbt_valid_to,
    FALSE AS dbt_is_deleted
FROM {{ ref('stg_bronze__users') }}
{% endset %}

{% do log("Bootstrap snapshot snp_empleado con fecha " ~ bootstrap_date, info=true) %}
{% do run_query(sql) %}
{% do log("Bootstrap completado.", info=true) %}

{% endmacro %}