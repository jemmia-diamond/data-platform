{{ config(
    materialized='view',
    schema='marts_sales'
) }}

SELECT * FROM {{ ref('dim_dates') }}
