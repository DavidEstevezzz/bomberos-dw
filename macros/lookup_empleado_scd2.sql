-- macros/lookup_empleado_scd2.sql

{#
  Resuelve empleado_key (versión SCD2 vigente en la fecha del hecho).
  Si no hay match → '-1' (Default Dimension Row).

  Uso:
    {{ lookup_empleado_scd2('h.id_empleado', 'h.fecha') }} AS empleado_key

  Genera el SQL del SELECT — el JOIN con dim_empleado lo gestiona el modelo.
#}
{% macro lookup_empleado_scd2(id_empleado_col, fecha_efecto_col, alias='de') %}
    COALESCE({{ alias }}.empleado_key, '-1')
{% endmacro %}


{#
  Cláusula JOIN para el lookup point-in-time contra dim_empleado.
  Rango semi-abierto [fecha_inicio_validez, fecha_fin_validez).

  Uso:
    LEFT JOIN {{ ref('dim_empleado') }} de
      {{ join_empleado_scd2('h.id_empleado', 'h.fecha') }}
#}
{% macro join_empleado_scd2(id_empleado_col, fecha_efecto_col, alias='de') %}
    ON {{ alias }}.id_empleado = {{ id_empleado_col }}
   AND {{ fecha_efecto_col }} >= {{ alias }}.fecha_inicio_validez
   AND ({{ fecha_efecto_col }} < {{ alias }}.fecha_fin_validez OR {{ alias }}.fecha_fin_validez IS NULL)
{% endmacro %}