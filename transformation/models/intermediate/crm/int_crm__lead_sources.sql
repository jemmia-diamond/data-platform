{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    lead_source_id,
    source_name,
    details,
    pancake_platform,
    pancake_page_id
FROM {{ ref('stg_erpnext__lead_sources') }}
