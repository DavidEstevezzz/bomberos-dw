{% macro limpiar_texto(campo) %}
    LOWER(TRIM({{ campo }}))
{% endmacro %}