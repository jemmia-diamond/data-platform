{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Design media reference — source of truth for the media JSON arrays (retouch, images, videos,
-- render images, try-on) attached to a design. Deduplicated to one row per design (latest with
-- non-empty retouch preferred) so downstream marts never fan out.
-- Grain: 1 row per design.
SELECT DISTINCT ON (design_id)
    design_id,
    retouch,
    images,
    videos,
    render_images,
    try_on_images,
    material_color,
    tick_sync_to_haravan,
    note
FROM {{ ref('stg_nocodb__design_design_images') }}
WHERE design_id IS NOT NULL
ORDER BY design_id,
         (retouch IS NULL OR retouch = '[]'),
         _db_updated_at DESC
