{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot date dimension — fully independent (own generate_series, no source from marts_core).
-- Grain: 1 row = 1 calendar date. Vietnamese-friendly labels for Metabase.

SELECT
    datum::date AS date,
    EXTRACT(YEAR FROM datum)::int AS year,
    EXTRACT(MONTH FROM datum)::int AS month,
    EXTRACT(QUARTER FROM datum)::int AS quarter,
    EXTRACT(WEEK FROM datum)::int AS week,
    EXTRACT(ISODOW FROM datum)::int AS day_of_week,
    TO_CHAR(datum, 'TMDay') AS day_name,
    TO_CHAR(datum, 'TMMonth') AS month_name,
    EXTRACT(ISODOW FROM datum) IN (6, 7) AS is_weekend,
    datum::date = DATE_TRUNC('month', datum)::date AS is_month_start,
    datum::date = (DATE_TRUNC('month', datum) + INTERVAL '1 month - 1 day')::date AS is_month_end,
    datum::date = DATE_TRUNC('quarter', datum)::date AS is_quarter_start,
    datum::date = (DATE_TRUNC('quarter', datum) + INTERVAL '3 month - 1 day')::date AS is_quarter_end
FROM generate_series('2020-01-01'::date, '2030-12-31'::date, '1 day'::interval) AS datum
