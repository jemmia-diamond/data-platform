{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                               AS inventory_id,
    loc_id::bigint                                                           AS location_id,
    variant_id::bigint                                                       AS variant_id,
    product_id::bigint                                                       AS product_id,
    qty_onhand::int                                                          AS qty_onhand,
    qty_commited::int                                                        AS qty_commited,
    qty_incoming::int                                                        AS qty_incoming,
    qty_available::int                                                       AS qty_available,
    updated_at::timestamp                                                    AS updated_at,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'inventory_locations') }}
