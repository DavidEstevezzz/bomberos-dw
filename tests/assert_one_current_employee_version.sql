SELECT
    id_empleado,
    COUNT(*) AS versiones_actuales
FROM {{ ref('dim_empleado') }}
WHERE es_version_actual = TRUE
  AND id_empleado <> -1
GROUP BY id_empleado
HAVING COUNT(*) > 1