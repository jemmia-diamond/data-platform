{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya wedding-ring feed — wedding rings that have a complete pair (both a male 'Nam' and female
-- 'Nữ' 'Nhẫn Cưới' design mapped to a live Haravan product), with a generated display title.
-- Wedding-ring identities are derived from int_catalog__designs (wedding_ring_id).
-- Grain: 1 row per wedding ring.
WITH valid_pairs AS (
    SELECT
        d.wedding_ring_id
    FROM {{ ref('int_catalog__designs') }} d
    JOIN {{ ref('int_catalog__products') }} p
        ON p.design_id = d.design_id
    WHERE d.wedding_ring_id IS NOT NULL
      AND d.gender IN ('Nam', 'Nữ')
      AND d.design_type = 'Nhẫn Cưới'
    GROUP BY d.wedding_ring_id
    HAVING COUNT(DISTINCT d.gender) = 2
)

SELECT
    d.wedding_ring_id                                                AS id,
    CONCAT('Nhẫn Cưới ', STRING_AGG(DISTINCT d.design_code, ' / '))  AS title
FROM {{ ref('int_catalog__designs') }} d
WHERE d.gender IN ('Nam', 'Nữ')
  AND d.design_type = 'Nhẫn Cưới'
  AND d.wedding_ring_id IN (SELECT wedding_ring_id FROM valid_pairs)
GROUP BY d.wedding_ring_id
