{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Collection membership + best active deal per entity (product or diamond) — source of truth for
-- "which Haravan collection applies to a product/diamond and what discount does it grant".
-- The mart selects best_deal_rank = 1 and computes the final sale price itself (presentation logic).
-- Grain: 1 row per (entity_type, entity_id, collection).
WITH membership AS (
    SELECT
        'product'::text AS entity_type,
        product_id AS entity_id,
        haravan_collection_id AS collection_id
    FROM {{ ref('stg_nocodb__products_haravan_collection') }}
    UNION ALL
    SELECT
        'diamond'::text AS entity_type,
        diamond_id AS entity_id,
        haravan_collection_id AS collection_id
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
),

joined AS (
    SELECT
        m.entity_type,
        m.entity_id,
        m.collection_id,
        c.collection_name,
        c.discount_type,
        c.discount_value,
        c.is_excluded,
        c.start_date,
        c.end_date,
        (c.start_date::timestamp <= now() AND c.end_date::timestamp >= now()) AS is_active
    FROM membership m
    JOIN {{ ref('int_catalog__haravan_collections') }} c
        ON c.collection_id = m.collection_id
)

SELECT
    entity_type,
    entity_id,
    collection_id,
    collection_name,
    discount_type,
    discount_value,
    is_excluded,
    is_active,
    ROW_NUMBER() OVER (
        PARTITION BY entity_type, entity_id
        ORDER BY is_active DESC,
                 (start_date IS NOT NULL) DESC,
                 discount_value DESC NULLS LAST
    ) AS best_deal_rank
FROM joined
