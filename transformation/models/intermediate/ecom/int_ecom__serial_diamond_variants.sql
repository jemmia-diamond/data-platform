{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Haravan variants that are part of a jewelry+diamond combo — a serial of the variant is linked
-- to a diamond via the NocoDB variant_serials_diamonds bridge. These variants are excluded from
-- the ecom jewelry variant feed (legacy excludeSerialsDiamondsSql).
-- Grain: 1 row per excluded Haravan variant_id.
SELECT DISTINCT wv.haravan_variant_id
FROM {{ ref('stg_nocodb__variants') }} wv
INNER JOIN {{ ref('stg_nocodb__variant_serials') }} vs
    ON vs.variant_id = wv.variant_id
INNER JOIN {{ ref('stg_nocodb__variant_serials_diamonds') }} vsd
    ON vsd.serial_id = vs.serial_id
WHERE wv.haravan_variant_id IS NOT NULL
