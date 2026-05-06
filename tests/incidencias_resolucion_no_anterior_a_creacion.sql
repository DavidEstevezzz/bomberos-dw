-- Test singular: validación temporal
--
-- Regla de negocio: una incidencia resuelta NUNCA puede tener fecha de
-- actualización (≈ resolución) anterior a su fecha de creación.
-- Si esta query devuelve filas → datos inconsistentes en el origen.
--
-- Severity: warn — el OLTP tiene corrupciones puntuales históricas;
-- queremos saberlo pero no bloquear el build por ello.

{{ config(severity='warn') }}

SELECT
    id_incidencia,
    fecha_creacion,
    fecha_actualizacion,
    estado,
    DATEDIFF('day', fecha_creacion, fecha_actualizacion) AS desfase_dias
FROM {{ ref('stg_bronze__incidents') }}
WHERE estado = 'resuelta'
  AND fecha_creacion IS NOT NULL
  AND fecha_actualizacion IS NOT NULL
  AND fecha_actualizacion < fecha_creacion