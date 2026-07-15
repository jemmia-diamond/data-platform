{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH design_images AS (
    SELECT
        design_id,
        count(*) FILTER (WHERE tick_sync_to_haravan) AS has_synced_image,
        count(*) AS image_count
    FROM {{ ref('stg_nocodb__design_design_images') }}
    GROUP BY 1
),

collections AS (
    SELECT * FROM {{ ref('stg_nocodb__collections') }}
)

SELECT
    d.design_id,
    d.wedding_ring_id,
    d.collections_id,
    d.design_code,
    d.design_code_legacy,
    d.erp_code,
    d.backup_code,
    d.design_type,
    d.gender,
    d._4view,
    d.usage_status,
    d.design_status,
    d.shape_of_main_stone,
    d.main_stone,
    d.diamond_holder,
    d.product_line,
    d.source,
    d.design_year,
    d.design_seq,
    d.variant_number,
    d.gold_weight,
    d.stone_quantity,
    d.stone_weight,
    d.published_scope,
    d.jewelry_rd_style,
    d.ring_band_type,
    d.ring_band_style,
    d.ring_head_style,
    d.ecom_showed,
    d.social_post,
    d.website,
    d.has_render,
    d.has_retouch,
    d.tag,
    d.created_date,
    COALESCE(i.image_count, 0)      AS image_count,
    COALESCE(i.has_synced_image, 0) > 0  AS has_synced_image,
    collections.collection_name,
    d.created_at,
    d.updated_at

FROM {{ ref('stg_nocodb__designs') }} d
LEFT JOIN design_images i ON i.design_id = d.design_id
LEFT JOIN collections ON collections.collection_id = d.collections_id
