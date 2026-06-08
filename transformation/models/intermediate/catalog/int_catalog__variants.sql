{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    hv.variant_id,
    hv.product_id,
    hp.title                                                               AS product_title,
    hp.product_type,
    hp.handle                                                              AS product_handle,
    hp.vendor,
    hp.published_scope,
    hp.published_at,
    hv.variant_title,
    hv.sku,
    hv.barcode,
    hv.price,
    hv.compare_at_price,
    hv.position,
    hv.option1,
    hv.option2,
    hv.option3,
    hv.taxable,
    hv.requires_shipping,
    hv.grams,
    hv.weight,
    hv.weight_unit,
    hv.inventory_quantity,
    hv.inventory_policy,
    hv.fulfillment_service,
    hv.inventory_management,
    hv.qty_onhand,
    hv.qty_commited,
    hv.qty_incoming,
    hv.qty_available,
    hv.image_id,
    hv.created_at,
    hv.updated_at,

    nv.variant_id                                                          AS nocodb_variant_id,
    nv.design_code,
    nv.design_type,
    nv.fineness,
    nv.material_color,
    nv.size_type,
    nv.ring_size,
    nv.estimated_gold_weight,
    nv.final_discount_price,

    nd.diamond_id,
    nd.carat                                                                AS diamond_carat,
    nd.shape                                                                AS diamond_shape,
    nd.color                                                                AS diamond_color,
    nd.clarity                                                              AS diamond_clarity,
    nd.fluorescence                                                         AS diamond_fluorescence,
    nd.cut                                                                  AS diamond_cut,
    nd.cogs                                                                 AS diamond_cogs,
    nd.vendor                                                               AS diamond_vendor,
    nd.report_lab,
    nd.report_no,
    nd.edge_size_1                                                          AS diamond_edge_size_1,
    nd.edge_size_2                                                          AS diamond_edge_size_2,
    ROUND(FLOOR(GREATEST(nd.edge_size_1, nd.edge_size_2) * 10) / 10, 1)    AS diamond_edge_size,
    CASE
        WHEN nd.edge_size_1 IS NOT NULL AND nd.edge_size_2 IS NOT NULL THEN
            CONCAT(ROUND(FLOOR(nd.edge_size_1 * 10) / 10, 1), ' x ', ROUND(FLOOR(nd.edge_size_2 * 10) / 10, 1))
    END                                                                     AS diamond_edge_size_display,
    nd.qty_onhand                                                           AS diamond_qty_onhand,
    nd.qty_available                                                        AS diamond_qty_available,
    nd.qty_commited                                                         AS diamond_qty_commited,
    nd.qty_incoming                                                         AS diamond_qty_incoming,
    nd.is_incoming                                                          AS diamond_is_incoming,
    nd.is_have_invoice                                                      AS diamond_is_have_invoice,
    nd.country_of_origin                                                    AS diamond_country_of_origin,
    nd.original_code                                                        AS diamond_original_code,
    nd.product_name                                                         AS diamond_product_name,

    nm.moissanite_id,
    nm.product_group                                                        AS moissanite_product_group,
    nm.shape                                                                AS moissanite_shape,
    nm.length                                                               AS moissanite_length,
    nm.width                                                                AS moissanite_width,
    nm.color                                                                AS moissanite_color,
    nm.clarity                                                              AS moissanite_clarity,
    nm.fluorescence                                                        AS moissanite_fluorescence,
    nm.cut                                                                  AS moissanite_cut,
    nm.polish                                                               AS moissanite_polish,
    nm.symmetry                                                             AS moissanite_symmetry,
    nm.price                                                                AS moissanite_price,
    nm.haravan_product_id                                                   AS moissanite_haravan_product_id,
    nm.haravan_variant_id                                                   AS moissanite_haravan_variant_id,
    nm.moissanite_serials                                                   AS moissanite_serials,
    nm.product_group_norm                                                   AS moissanite_product_group_norm,
    nm.shape_norm                                                           AS moissanite_shape_norm,
    nm.length_norm                                                          AS moissanite_length_norm,
    nm.width_norm                                                           AS moissanite_width_norm,
    nm.color_norm                                                           AS moissanite_color_norm,
    nm.clarity_norm                                                         AS moissanite_clarity_norm,
    nm.fluorescence_norm                                                   AS moissanite_fluorescence_norm,
    nm.cut_norm                                                             AS moissanite_cut_norm,
    nm.polish_norm                                                          AS moissanite_polish_norm,
    nm.symmetry_norm                                                        AS moissanite_symmetry_norm

FROM {{ ref('stg_haravan__product_variants') }} hv
LEFT JOIN {{ ref('stg_haravan__products') }} hp
    ON hv.product_id = hp.product_id
LEFT JOIN {{ ref('stg_nocodb__variants') }} nv
    ON hv.variant_id = nv.haravan_variant_id
LEFT JOIN {{ ref('stg_nocodb__diamonds') }} nd
    ON hv.variant_id = nd.haravan_variant_id
LEFT JOIN {{ ref('stg_nocodb__moissanite') }} nm
    ON hv.variant_id = nm.haravan_variant_id
