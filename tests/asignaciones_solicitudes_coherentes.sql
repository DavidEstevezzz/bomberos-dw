-- Test singular: validación cross-model
--
-- Regla de negocio: el contador "total_asignaciones_generadas" en cada
-- fila de fact_solicitudes debe coincidir con el número real de
-- asignaciones en stg_bronze__firefighters_assignments para esa solicitud.
--
-- Si difieren, el cálculo agregado en la fact está fuera de sincronía
-- respecto al staging — síntoma de un bug en el COALESCE/JOIN.

WITH

asignaciones_reales AS (
    SELECT
        id_solicitud,
        COUNT(*) AS total_real
    FROM {{ ref('stg_bronze__firefighters_assignments') }}
    WHERE id_solicitud IS NOT NULL
    GROUP BY 1
),

asignaciones_en_fact AS (
    SELECT
        id_solicitud,
        total_asignaciones_generadas AS total_fact
    FROM {{ ref('fact_solicitudes') }}
    WHERE total_asignaciones_generadas > 0
)

SELECT
    f.id_solicitud,
    f.total_fact,
    r.total_real,
    f.total_fact - r.total_real AS diferencia
FROM asignaciones_en_fact f
INNER JOIN asignaciones_reales r
    ON f.id_solicitud = r.id_solicitud
WHERE f.total_fact <> r.total_real