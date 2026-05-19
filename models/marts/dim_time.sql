{{
    config(
        materialized='table'
    )
}}

WITH spine AS (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('" ~ var('calendar_start_date', '2020-01-01') ~ "' as date)",
        end_date="cast('" ~ var('calendar_end_date', '2030-12-31') ~ "' as date)"
    ) }}
)

SELECT
    CAST(date_day AS DATE) AS date_day
FROM spine