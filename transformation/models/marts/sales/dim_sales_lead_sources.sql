{{ config(
    materialized='materialized_view',
    schema='marts_sales'
) }}

WITH lead_sources AS (
    SELECT * FROM {{ ref('int_crm__lead_sources') }}
)

SELECT
    lead_source_id,
    source_name,
    details,
    pancake_platform,
    pancake_page_id
FROM lead_sources
