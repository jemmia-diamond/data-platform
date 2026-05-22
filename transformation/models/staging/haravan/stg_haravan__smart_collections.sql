{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                               AS collection_id,
    title,
    handle,
    published::boolean                                                       AS published,
    published_scope,
    published_at::timestamp                                                  AS published_at,
    sort_order,
    template_suffix,
    body_html,
    image,
    rules,
    disjunctive::boolean                                                     AS disjunctive,
    updated_at::timestamp                                                    AS updated_at,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'smart_collections') }}
