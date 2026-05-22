{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint                                                           AS product_id,
        jsonb_array_elements(images)                                         AS img
    FROM {{ source('haravan', 'products') }}
    WHERE images IS NOT NULL
      AND jsonb_typeof(images) = 'array'
)

SELECT
    (img->>'id')::bigint                                                     AS image_id,
    product_id,
    img->>'src'                                                              AS src,
    img->>'filename'                                                         AS filename,
    (img->>'position')::int                                                  AS position,
    img->>'variant_ids'                                                      AS variant_ids,
    (img->>'created_at')::timestamp                                          AS created_at,
    (img->>'updated_at')::timestamp                                          AS updated_at

FROM unnested
