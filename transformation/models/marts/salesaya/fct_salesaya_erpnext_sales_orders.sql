{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    sales_order_id                                                       AS id,
    customer_id                                                          AS customer,
    fulfillment_status,
    updated_at                                                           AS modified
FROM {{ ref('stg_erpnext__sales_orders') }}
