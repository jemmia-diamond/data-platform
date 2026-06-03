{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    preferred_product_id,
    lead_id,
    product_type,
    idx
FROM {{ ref('stg_erpnext__lead_preferred_products') }}
