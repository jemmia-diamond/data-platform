{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    line_item_id                                                         AS id,
    variant_id,
    product_id
FROM {{ ref('stg_haravan__order_lines') }}
