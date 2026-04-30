{% macro campos_auditoria() %}
    , CREATED_AT AS fecha_creacion
    , UPDATED_AT AS fecha_actualizacion
{% endmacro %}