{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    image_id                                                             AS id,
    design_id,
    images,
    videos,
    render_images,
    retouch,
    try_on_images,
    _4view                                                                AS "4view",
    created_at                                                           AS database_created_at,
    updated_at                                                           AS database_updated_at,
    material_color
FROM {{ ref('stg_nocodb__design_design_images') }}
