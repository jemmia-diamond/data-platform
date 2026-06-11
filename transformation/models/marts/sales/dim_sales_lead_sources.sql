{{ config(
    materialized='materialized_view',
    schema='marts_sales'
) }}

WITH lead_sources AS (
    SELECT * FROM {{ ref('int_crm__lead_sources') }}
)

SELECT
    lead_source_id,
    {{ filter_text('source_name') }} AS source_name,
    {{ filter_text('details') }} AS details,
    {{ filter_text('pancake_platform') }} AS pancake_platform,
    pancake_page_id
FROM lead_sources
