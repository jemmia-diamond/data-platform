{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint                                                           AS product_id,
        jsonb_array_elements(options)                                        AS opt
    FROM {{ source('haravan', 'products') }}
    WHERE options IS NOT NULL
      AND jsonb_typeof(options) = 'array'
)

SELECT
    (opt->>'id')::bigint                                                     AS option_id,
    product_id,
    opt->>'name'                                                             AS name,
    (opt->>'position')::int                                                  AS position

FROM unnested
