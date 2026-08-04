{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["design_id", "material_color"]}]
) }}

-- Ecom design imagery — per (design, material_color) array of CDN-rewritten image URLs.
-- Replaces the legacy worker LATERAL image join + workplace→CDN URL rewrite. The NocoDB
-- design_images.retouch column is a JSON array of {url,...} objects; we extract each url,
-- rewrite the workplace R2 host (https://jemmia-workplace.<hash>.r2.cloudflarestorage.com)
-- to the CDN host (https://cdn.jemmia.vn), and aggregate per material_color.
-- Grain: 1 row per (design_id, material_color).
WITH elements AS (
    SELECT
        di.design_id,
        di.material_color,
        (elem ->> 'url') AS url
    FROM {{ ref('stg_nocodb__design_design_images') }} di
    CROSS JOIN LATERAL jsonb_array_elements(di.retouch::jsonb) AS elem
    WHERE di.retouch IS NOT NULL
      AND jsonb_typeof(di.retouch::jsonb) = 'array'
      AND di.design_id IS NOT NULL
)

SELECT
    design_id,
    material_color,
    array_agg(
        regexp_replace(
            url,
            '^https://jemmia-workplace\.[0-9a-f]+\.r2\.cloudflarestorage\.com',
            'https://cdn.jemmia.vn'
        )
        ORDER BY url
    ) AS images
FROM elements
WHERE url IS NOT NULL
GROUP BY design_id, material_color
