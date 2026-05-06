-- Test singular: validación temporal
--
-- Regla de negocio: si una solicitud tiene fecha_fin definida, NUNCA
-- puede ser anterior a fecha_inicio. Una solicitud "termina antes de
-- empezar" es por definición un dato corrupto.

SELECT
    id_solicitud,
    id_empleado,
    tipo_permiso,
    fecha_inicio,
    fecha_fin,
    DATEDIFF('day', fecha_inicio, fecha_fin) AS dias_desfase
FROM {{ ref('stg_bronze__requests') }}
WHERE fecha_inicio IS NOT NULL
  AND fecha_fin IS NOT NULL
  AND fecha_fin < fecha_inicio