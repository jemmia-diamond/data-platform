{{ config(
    materialized='view',
    schema='staging'
) }}

-- Haravan collects: product <-> Haravan collection mapping (fn haravan.collection_product).
SELECT
    id::bigint                                                               AS collect_id,
    collection_id::bigint                                                    AS collection_id,
    product_id::bigint                                                       AS product_id,
    featured::boolean                                                        AS featured,
    position::int                                                            AS position,
    sort_value,
    updated_at::timestamp                                                    AS updated_at,
    created_at::timestamp                                                    AS created_at,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'collection_product') }}
