{% macro bootstrap_snp_empleado() %}

{# 
  Bootstrap del snapshot SCD2 de empleados.
  
  Inicializa snp_empleado con una versión por empleado fechada en 
  '2024-01-01' (anterior al primer hecho histórico: 2024-02-13).
  
  Necesario porque dbt snapshot, en su primera ejecución, fecharía 
  dbt_valid_from = NOW() y dejaría todos los hechos históricos huérfanos.
  
  Ejecutar UNA SOLA VEZ tras DROP TABLE del snapshot existente:
    dbt run-operation bootstrap_snp_empleado
  
  Después, ejecutar `dbt snapshot` normalmente para capturar cambios.
#}

{% set bootstrap_date = '2024-01-01 00:00:00' %}
{% set snapshot_schema = 'DBT_DESTEVEZ' %}

{% set sql %}
CREATE OR REPLACE TRANSIENT TABLE {{ target.database }}.{{ snapshot_schema }}.snp_empleado AS
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