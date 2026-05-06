-- Test singular: validación de agregación
--
-- Regla de negocio: la suma del coste mensual de horas extra calculado
-- desde la fact debe coincidir con el cálculo manual desde staging
-- (horas × precio). Si difieren, hay un bug en el cálculo de la fact.
--
-- Tolerancia: 0.01€ (1 céntimo) por redondeos de DECIMAL.

WITH

coste_desde_fact AS (
    SELECT
        DATE_TRUNC('month', fecha) AS mes,
        ROUND(SUM(coste_total), 2) AS coste_fact
    FROM {{ ref('fact_horas_extra') }}
    GROUP BY 1
),

coste_desde_staging AS (
    SELECT
        DATE_TRUNC('month', eh.fecha) AS mes,
        ROUND(
            SUM(eh.horas_diurnas * s.precio_hora_diurna)
            + SUM(eh.horas_nocturnas * s.precio_hora_nocturna),
            2
        ) AS coste_calculado
    FROM {{ ref('stg_bronze__extra_hours') }} eh
    INNER JOIN {{ ref('stg_bronze__salaries') }} s
        ON eh.id_salario = s.id_salario
    GROUP BY 1
)

SELECT
    f.mes,
    f.coste_fact,
    c.coste_calculado,
    ABS(f.coste_fact - c.coste_calculado) AS diferencia
FROM coste_desde_fact f
INNER JOIN coste_desde_staging c
    ON f.mes = c.mes
WHERE ABS(f.coste_fact - c.coste_calculado) > 0.01