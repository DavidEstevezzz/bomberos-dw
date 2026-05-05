{{
    config(
        materialized='table'
    )
}}

WITH spine AS (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2030-12-31' as date)"
    ) }}
)

SELECT
    CAST(date_day AS DATE) AS date_day
FROM spine