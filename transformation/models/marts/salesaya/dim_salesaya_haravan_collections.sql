{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya collection feed — Haravan collections (discount configuration + validity window).
-- Grain: 1 row per Haravan collection.
SELECT
    collection_id   AS id,
    collection_name AS title,
    discount_type,
    discount_value,
    start_date,
    end_date
FROM {{ ref('int_catalog__haravan_collections') }}
