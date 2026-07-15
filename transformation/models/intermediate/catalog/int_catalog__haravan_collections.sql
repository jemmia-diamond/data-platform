{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH haravan_collections AS (
    SELECT * FROM {{ ref('stg_nocodb__haravan_collections') }}
)

SELECT
    haravan_collection_id,
    collection_type,
    title,
    products_count,
    haravan_id,
    auto_create,
    is_excluded,
    is_exclusive,
    discount_type,
    discount_value,
    start_date,
    end_date
FROM haravan_collections
