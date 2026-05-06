-- Test singular: validación de rango lógico
--
-- Regla de negocio del cuerpo de bomberos: una guardia operativa dura
-- máximo 24 horas. Por tanto, ningún registro de horas extra puede
-- exceder 24 horas en total para un mismo bombero y día.
--
-- Si esta query devuelve filas → posible doble registro o error de carga.

{{ config(severity='warn') }}

SELECT
    id_empleado,
    fecha,
    SUM(total_horas) AS total_horas_dia,
    COUNT(*) AS num_registros
FROM {{ ref('stg_bronze__extra_hours') }}
GROUP BY id_empleado, fecha
HAVING SUM(total_horas) > 24