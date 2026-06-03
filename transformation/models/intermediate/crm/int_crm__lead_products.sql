{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    lead_demand_id AS lead_product_id,
    product_type
FROM {{ ref('stg_erpnext__lead_products') }}
