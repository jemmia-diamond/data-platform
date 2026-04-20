{{ config(
    materialized='table',
    schema='analytics'
) }}

SELECT
    datum AS date_actual,
    TO_CHAR(datum, 'TMDay') AS day_name,
    EXTRACT(ISODOW FROM datum) AS day_of_week,
    EXTRACT(DAY FROM datum) AS day_of_month,
    EXTRACT(WEEK FROM datum) AS week_of_year,
    EXTRACT(MONTH FROM datum) AS month_actual,
    TO_CHAR(datum, 'TMMonth') AS month_name,
    TO_CHAR(datum, 'Mon') AS month_name_short,
    TO_CHAR(datum, 'MM-YYYY') AS month_year,
    CAST(TO_CHAR(datum, 'YYYYMM') AS INT) AS year_month_int,
    EXTRACT(QUARTER FROM datum) AS quarter,
    EXTRACT(YEAR FROM datum) AS year_actual,
    CASE WHEN EXTRACT(ISODOW FROM datum) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN (datum + INTERVAL '1 day')::DATE = (DATE_TRUNC('month', datum) + INTERVAL '1 month')::DATE 
         THEN TRUE ELSE FALSE END AS is_last_day_of_month,
    'Normal Day' AS event_name
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) datum