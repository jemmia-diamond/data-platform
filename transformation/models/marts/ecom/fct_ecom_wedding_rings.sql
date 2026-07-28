{{ config(
    schema='marts_ecom'
) }}

-- Ecom wedding rings feed — replaces the legacy `ecom.materialized_wedding_rings` MVIEW AND the
-- runtime nesting the wedding list/detail API builds (products → variants JSON). One row per
-- wedding ring (NocoDB designs.wedding_ring_id).
-- Prices use the RAW Haravan variant price (the legacy wedding API shows raw price, no 3-branch
-- discount). fineness and material_colors are text arrays (legacy MVIEW used comma-separated text
-- + LIKE ANY; the fn Worker must switch to = ANY / && when consuming the aggregate columns).
WITH members AS (
    SELECT
        d.wedding_ring_id,
        p.product_id,
        p.title,
        np.ecom_title,
        p.handle,
        p.product_type,
        p.images,
        d.design_code,
        d.diamond_holder,
        d.gender,
        CASE WHEN d.ring_band_type = 'None' THEN NULL ELSE d.ring_band_type END AS ring_band_type,
        d.ring_band_style,
        COALESCE(d.created_date::timestamp, d.created_at)               AS created_date
    FROM {{ ref('int_catalog__designs') }} d
    INNER JOIN {{ ref('int_catalog__products') }} p
        ON p.design_id = d.design_id
    LEFT JOIN {{ ref('stg_nocodb__products') }} np
        ON np.haravan_product_id = p.product_id
    WHERE d.wedding_ring_id IS NOT NULL
),

ring_stats AS (
    SELECT
        vm.wedding_ring_id,
        MAX(v.price)                                                          AS max_price,
        MIN(v.price)                                                          AS min_price,
        COALESCE(SUM(v.qty_onhand), 0)                                        AS qty_onhand,
        array_agg(DISTINCT v.fineness) FILTER (WHERE v.fineness IS NOT NULL)          AS fineness,
        array_agg(DISTINCT v.material_color) FILTER (WHERE v.material_color IS NOT NULL) AS material_colors
    FROM members vm
    INNER JOIN {{ ref('int_catalog__variants') }} v
        ON v.product_id = vm.product_id
    GROUP BY vm.wedding_ring_id
),

ring_sold AS (
    SELECT
        m.wedding_ring_id,
        COALESCE(SUM(sm.sold_quantity), 0) AS sold_quantity
    FROM members m
    LEFT JOIN {{ ref('int_ecom__sold_metrics') }} sm
        ON sm.product_id = m.product_id
    GROUP BY m.wedding_ring_id
),

ring_design_attrs AS (
    SELECT
        wedding_ring_id,
        array_agg(DISTINCT ring_band_style) FILTER (WHERE ring_band_style IS NOT NULL) AS ring_band_styles,
        MAX(created_date) AS created_date
    FROM members
    GROUP BY wedding_ring_id
),

variant_json AS (
    SELECT
        vm.wedding_ring_id,
        vm.product_id,
        jsonb_agg(
            jsonb_build_object(
                'id', v.variant_id,
                'fineness', v.fineness,
                'material_color', v.material_color,
                'ring_size', v.ring_size,
                'price', v.price,
                'compare_at_price', v.compare_at_price,
                'inventory_quantity', v.qty_available,
                'title', v.variant_title,
                'available', v.qty_available > 0
            )
        ) AS variants
    FROM members vm
    INNER JOIN {{ ref('int_catalog__variants') }} v
        ON v.product_id = vm.product_id
    GROUP BY vm.wedding_ring_id, vm.product_id
)

SELECT
    m.wedding_ring_id                                                  AS id,
    'Nhẫn Cưới ' || string_agg(DISTINCT m.design_code, ' / ' ORDER BY m.design_code) AS title,
    rs.max_price,
    rs.min_price,
    rs.qty_onhand,
    rsl.sold_quantity,
    rs.fineness,
    rs.material_colors,
    rda.ring_band_styles,
    rda.created_date,
    jsonb_agg(
        jsonb_build_object(
            'id', m.product_id,
            'product_type', m.product_type,
            'title', COALESCE(m.ecom_title, m.title),
            'ring_band_type', m.ring_band_type,
            'design_code', m.design_code,
            'diamond_holder', m.diamond_holder,
            'gender', m.gender,
            'handle', m.handle,
            'variants', vj.variants,
            'images', COALESCE((SELECT array_agg(elem ->> 'src' ORDER BY (elem ->> 'position')::int NULLS LAST)
                                FROM jsonb_array_elements(m.images::jsonb) elem), ARRAY[]::text[])
        )
    )                                                                   AS products

FROM members m
INNER JOIN ring_stats rs
    ON rs.wedding_ring_id = m.wedding_ring_id
INNER JOIN ring_sold rsl
    ON rsl.wedding_ring_id = m.wedding_ring_id
INNER JOIN ring_design_attrs rda
    ON rda.wedding_ring_id = m.wedding_ring_id
INNER JOIN variant_json vj
    ON vj.wedding_ring_id = m.wedding_ring_id
   AND vj.product_id = m.product_id
LEFT JOIN {{ ref('int_ecom__sold_metrics') }} sm
    ON sm.product_id = m.product_id
GROUP BY
    m.wedding_ring_id,
    rs.max_price, rs.min_price, rs.qty_onhand, rs.fineness, rs.material_colors,
    rsl.sold_quantity, rda.ring_band_styles, rda.created_date
