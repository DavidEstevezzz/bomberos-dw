{#
  Normalización canónica de texto para campos categóricos en staging.
  
    1. TRIM espacios externos (datos sucios del OLTP)
    2. LOWER para case-insensitive (los enums vienen mezclados: 'IDA', 'ida', 'Ida')
    3. NULLIF '' a NULL (un string vacío no es información, debe ser NULL)
  
  Uso:
    {{ limpiar_texto('TURNO') }} AS turno
#}
{% macro limpiar_texto(campo) %}
    NULLIF(LOWER(TRIM({{ campo }})), '')
{% endmacro %}