{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    hp.product_id,
    hp.title,
    hp.handle,
    hp.body_html,
    hp.product_type,
    hp.vendor,
    hp.published_scope,
    hp.published_at,
    hp.tags,
    hp.variant_count,
    hp.image_count,
    hp.only_hide_from_list,
    hp.not_allow_promotion,
    hp.template_suffix,
    hp.created_at,
    hp.updated_at,

    np.product_id                                                       AS nocodb_product_id,
    np.design_id,
    np.design_code,
    np.price_min                                                        AS nocodb_price_min,
    np.price_max                                                        AS nocodb_price_max,
    np.estimated_gold_weight,
    np.has_360

FROM {{ ref('stg_haravan__products') }} hp
LEFT JOIN {{ ref('stg_nocodb__products') }} np
    ON hp.product_id = np.haravan_product_id
