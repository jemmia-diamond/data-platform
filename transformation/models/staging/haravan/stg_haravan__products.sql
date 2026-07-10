{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                      AS product_id,
    title,
    handle,
    body_html,
    template_suffix,
    product_type,
    vendor,
    published_scope,
    published_at::timestamp                                          AS published_at,
    tags,
    jsonb_array_length(variants)::int                               AS variant_count,
    jsonb_array_length(images)::int                                 AS image_count,
    only_hide_from_list,
    not_allow_promotion,
    created_at::timestamp                                            AS created_at,
    updated_at::timestamp                                            AS updated_at,
    _db_updated_at::timestamp                                        AS _db_updated_at,
    _dlt_load_id,
    _dlt_id,
    images

FROM {{ source('haravan', 'products') }}
