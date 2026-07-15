{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH diamond_collection_links AS (
    SELECT * FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
),

haravan_collections AS (
    SELECT * FROM {{ ref('int_catalog__haravan_collections') }}
),

linked_collections AS (
    SELECT
        diamond_collection_links.diamond_id,
        haravan_collections.haravan_collection_id,
        haravan_collections.title,
        haravan_collections.is_excluded,
        haravan_collections.discount_type,
        haravan_collections.discount_value
    FROM diamond_collection_links
    JOIN haravan_collections
        ON haravan_collections.haravan_collection_id = diamond_collection_links.haravan_collection_id
),

collection_json AS (
    SELECT
        diamond_id,
        json_agg(json_build_object(
            'id', haravan_collection_id,
            'name', title,
            'is_excluded', is_excluded,
            'discount_type', discount_type,
            'discount_value', discount_value
        )) AS collections
    FROM linked_collections
    GROUP BY diamond_id
),

best_deal AS (
    SELECT DISTINCT ON (diamond_id)
        diamond_id,
        discount_type,
        discount_value
    FROM linked_collections
    ORDER BY diamond_id, discount_value DESC
)

SELECT
    collection_json.diamond_id,
    collection_json.collections,
    best_deal.discount_type,
    best_deal.discount_value
FROM collection_json
LEFT JOIN best_deal
    ON best_deal.diamond_id = collection_json.diamond_id
