{#
  Genera un comentario JSON para cada query enviada a Snowflake.
  Permite trazabilidad desde QUERY_HISTORY:
    - qué modelo dbt lanzó la query
    - desde qué entorno se ejecutó
    - qué ejecución concreta de dbt la generó
    - qué versión de dbt se usó

  Uso en FinOps: agrupar costes de cómputo por modelo, capa o ejecución.
  Uso en debugging: identificar queries problemáticas sin abrir dbt.
#}

{% macro query_comment(node) %}
    {%- set comment_dict = {} -%}
    {%- do comment_dict.update(
        app='dbt',
        dbt_version=dbt_version,
        invocation_id=invocation_id,
        profile_name=target.get('profile_name'),
        target_name=target.get('name'),
        database=target.get('database'),
        schema=target.get('schema'),
        node_id=node.unique_id if node else 'unknown',
        node_name=node.name if node else 'unknown',
        node_alias=node.alias if node else 'unknown',
        node_resource_type=node.resource_type if node else 'unknown',
        package_name=node.package_name if node else 'unknown'
    ) -%}
    {{ return(tojson(comment_dict)) }}
{% endmacro %}