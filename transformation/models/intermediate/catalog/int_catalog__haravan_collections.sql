{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Haravan collection reference (discount collections from NocoDB) — source of truth for
-- collection title + discount configuration + validity window.
-- Grain: 1 row per Haravan collection.
SELECT
    haravan_collection_id AS collection_id,
    collection_type,
    title AS collection_name,
    products_count,
    haravan_id,
    auto_create,
    is_excluded,
    is_exclusive,
    discount_type,
    discount_value,
    start_date,
    end_date,
    _db_updated_at
FROM {{ ref('stg_nocodb__haravan_collections') }}
