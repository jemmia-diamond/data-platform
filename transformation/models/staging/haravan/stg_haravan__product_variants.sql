{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id                                                               AS product_id,
        _db_updated_at,
        jsonb_array_elements(variants)                                   AS variant
    FROM {{ source('haravan', 'products') }}
    WHERE variants IS NOT NULL
      AND jsonb_typeof(variants) = 'array'
)

SELECT
    (variant->>'id')::bigint                                            AS variant_id,
    product_id,
    variant->>'title'                                                   AS variant_title,
    variant->>'sku'                                                     AS sku,
    variant->>'barcode'                                                 AS barcode,
    (variant->>'price')::numeric                                        AS price,
    (variant->>'compare_at_price')::numeric                             AS compare_at_price,
    (variant->>'position')::int                                         AS position,
    variant->>'option1'                                                 AS option1,
    variant->>'option2'                                                 AS option2,
    variant->>'option3'                                                 AS option3,
    (variant->>'taxable')::boolean                                      AS taxable,
    (variant->>'image_id')::bigint                                      AS image_id,
    (variant->>'inventory_quantity')::int                               AS inventory_quantity,
    (variant->>'old_inventory_quantity')::int                           AS old_inventory_quantity,
    variant->>'inventory_policy'                                        AS inventory_policy,
    variant->>'fulfillment_service'                                     AS fulfillment_service,
    (variant->>'requires_shipping')::boolean                            AS requires_shipping,
    variant->>'inventory_management'                                    AS inventory_management,
    (variant->>'grams')::numeric                                        AS grams,
    variant->>'weight'                                                  AS weight,
    variant->>'weight_unit'                                             AS weight_unit,
    ((variant->>'inventory_advance')::jsonb->>'qty_onhand')::int        AS qty_onhand,
    ((variant->>'inventory_advance')::jsonb->>'qty_commited')::int      AS qty_commited,
    ((variant->>'inventory_advance')::jsonb->>'qty_incoming')::int      AS qty_incoming,
    ((variant->>'inventory_advance')::jsonb->>'qty_available')::int     AS qty_available,
    (variant->>'created_at')::timestamp                                 AS created_at,
    (variant->>'updated_at')::timestamp                                 AS updated_at,
    _db_updated_at::timestamp                                           AS _db_updated_at

FROM unnested
