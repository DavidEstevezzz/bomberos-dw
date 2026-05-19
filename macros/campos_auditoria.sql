{% macro campos_auditoria() %}
    , CREATED_AT::TIMESTAMP_NTZ AS fecha_creacion
    , UPDATED_AT::TIMESTAMP_NTZ AS fecha_actualizacion
    , _LOADED_AT::TIMESTAMP_NTZ AS fecha_carga_bronze
{% endmacro %}