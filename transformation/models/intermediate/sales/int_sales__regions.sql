{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    region_id,
    region_name
FROM {{ ref('stg_erpnext__regions') }}
