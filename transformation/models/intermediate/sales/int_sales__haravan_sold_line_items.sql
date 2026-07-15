{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT DISTINCT
    variant_id,
    product_id
FROM {{ ref('stg_haravan__order_lines') }}
