{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Payment entries unnested from ERPNext sales orders.
-- Grain: 1 row = 1 payment entry (an order can have multiple entries).
-- Passthrough from staging — all JSON parsing logic lives in stg_erpnext__sales_payment_entries.
select *
from {{ ref('stg_erpnext__sales_payment_entries') }}
