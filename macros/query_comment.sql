{#
  Genera un comentario JSON para cada query enviada a Snowflake.
  Permite trazabilidad desde QUERY_HISTORY:
    - ¿qué modelo dbt lanzó esta query?
    - ¿desde qué entorno (dev/prod)?
    - ¿qué versión de dbt?

  Uso en FinOps: agrupar costes de cómputo por modelo.
  Uso en debugging: identificar queries problemáticas sin abrir dbt.
#}

{% macro query_comment(node) %}
    {%- set comment_dict = {} -%}
    {%- do comment_dict.update(
        app='dbt',
        dbt_version=dbt_version,
        profile_name=target.get('profile_name'),
        target_name=target.get('name'),
        node_id=node.unique_id if node else 'unknown',
        node_alias=node.alias if node else 'unknown',
        node_resource_type=node.resource_type if node else 'unknown'
    ) -%}
    {{ return(tojson(comment_dict)) }}
{% endmacro %}