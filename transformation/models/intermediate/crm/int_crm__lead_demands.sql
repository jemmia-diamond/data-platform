{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    lead_demand_id,
    demand_label
FROM {{ ref('stg_erpnext__lead_demands') }}
