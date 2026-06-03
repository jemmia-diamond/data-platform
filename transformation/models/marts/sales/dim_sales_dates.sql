{{ config(
    materialized='table',
    schema='marts_sales'
) }}

SELECT * FROM {{ ref('dim_dates') }}
