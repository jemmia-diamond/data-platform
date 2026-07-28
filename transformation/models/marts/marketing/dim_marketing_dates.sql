{{ config(
    schema='marts_marketing'
) }}

SELECT * FROM {{ ref('dim_dates') }}
