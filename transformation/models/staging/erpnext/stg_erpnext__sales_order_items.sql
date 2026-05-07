{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested_items AS (
    SELECT
        -- Get metadata from parent table (Sales Order)
        name AS _parent_order_name,
        _db_updated_at,
        _dlt_load_id,
        _dlt_id,
        -- Unnest JSON array into rows
        jsonb_array_elements(sales_order_items::jsonb) AS item
    FROM {{ source('erpnext', 'sales_orders') }}
    WHERE sales_order_items IS NOT NULL 
      AND sales_order_items != '[]'
      -- still filter out deleted sales orders
      AND name NOT IN (
          SELECT deleted_name
          FROM {{ source('erpnext', 'deleted_documents') }}
          WHERE deleted_doctype = 'Sales Order'
            AND (restored IS NULL OR restored = 0)
      )
)

SELECT
    -- Primary Key & Parent Link
    item->>'name' AS sales_order_item_id,
    item->>'parent' AS sales_order_id,
    item->>'parenttype' AS parent_type,
    item->>'parentfield' AS parent_field,
    (item->>'idx')::int AS line_item_idx,
    
    -- Item Identification
    item->>'sku' AS sku,
    item->>'item_name' AS item_name,
    item->>'variant_title' AS variant_title,
    item->>'barcode' AS barcode,
    item->>'image' AS image,
    
    -- Haravan Integration
    (item->>'haravan_variant_id')::bigint AS haravan_variant_id,
    
    -- Quantities
    (item->>'qty')::numeric AS qty,
    (item->>'stock_qty')::numeric AS stock_qty,
    (item->>'ordered_qty')::numeric AS ordered_qty,
    (item->>'delivered_qty')::numeric AS delivered_qty,
    (item->>'picked_qty')::numeric AS picked_qty,
    (item->>'returned_qty')::numeric AS returned_qty,
    (item->>'actual_qty')::numeric AS actual_qty,
    (item->>'planned_qty')::numeric AS planned_qty,
    (item->>'produced_qty')::numeric AS produced_qty,
    (item->>'projected_qty')::numeric AS projected_qty,
    (item->>'requested_qty')::numeric AS requested_qty,
    (item->>'stock_reserved_qty')::numeric AS stock_reserved_qty,
    (item->>'subcontracted_qty')::numeric AS subcontracted_qty,
    (item->>'work_order_qty')::numeric AS work_order_qty,
    (item->>'fg_item_qty')::numeric AS fg_item_qty,
    
    -- UOM & Conversions
    item->>'uom' AS uom,
    item->>'stock_uom' AS stock_uom,
    (item->>'conversion_factor')::numeric AS conversion_factor,
    
    -- Financials (Transaction Currency)
    (item->>'rate')::numeric AS rate,
    (item->>'amount')::numeric AS amount,
    (item->>'net_rate')::numeric AS net_rate,
    (item->>'net_amount')::numeric AS net_amount,
    (item->>'price_list_rate')::numeric AS price_list_rate,
    (item->>'discount_amount')::numeric AS discount_amount,
    (item->>'discount_percentage')::numeric AS discount_percentage,
    (item->>'distributed_discount_amount')::numeric AS distributed_discount_amount,
    (item->>'billed_amt')::numeric AS billed_amt,
    (item->>'rate_with_margin')::numeric AS rate_with_margin,
    (item->>'margin_rate_or_amount')::numeric AS margin_rate_or_amount,
    item->>'margin_type' AS margin_type,
    (item->>'gross_profit')::numeric AS gross_profit,
    (item->>'valuation_rate')::numeric AS valuation_rate,
    
    -- Financials (Base Currency)
    (item->>'base_rate')::numeric AS base_rate,
    (item->>'base_amount')::numeric AS base_amount,
    (item->>'base_net_rate')::numeric AS base_net_rate,
    (item->>'base_net_amount')::numeric AS base_net_amount,
    (item->>'base_price_list_rate')::numeric AS base_price_list_rate,
    (item->>'base_rate_with_margin')::numeric AS base_rate_with_margin,
    
    -- Product Specifics (Diamonds/Jewelry)
    item->>'serial_numbers' AS serial_numbers,
    item->>'serial' AS serial,
    item->>'diamond_details' AS diamond_details,
    item->>'product_details' AS product_details,
    (item->>'weight_per_unit')::numeric AS weight_per_unit,
    (item->>'total_weight')::numeric AS total_weight,
    item->>'weight_uom' AS weight_uom,
    
    -- Promotions & Pricing Rules
    item->>'promotion' AS promotion,
    item->>'promotion_1' AS promotion_1,
    item->>'promotion_2' AS promotion_2,
    item->>'promotion_3' AS promotion_3,
    item->>'promotion_4' AS promotion_4,
    item->>'promotion_5' AS promotion_5,
    item->>'new_promotions' AS new_promotions,
    item->>'pricing_rules' AS pricing_rules,
    item->>'discount_rate' AS discount_rate,
    
    -- Status & Workflow
    (item->>'docstatus')::int AS docstatus,
    item->>'product_availability_status' AS product_availability_status,
    item->>'type' AS item_type,
    item->>'item_policy' AS item_policy,
    item->>'item_tax_rate' AS item_tax_rate,
    item->>'cost_center' AS cost_center,
    item->>'warehouse' AS warehouse,
    
    -- Blanket Orders
    (item->>'against_blanket_order')::int::boolean AS against_blanket_order,
    (item->>'blanket_order_rate')::numeric AS blanket_order_rate,
    
    -- Flags (Booleans)
    (item->>'is_free_item')::int::boolean AS is_free_item,
    (item->>'is_stock_item')::int::boolean AS is_stock_item,
    (item->>'is_policy_locked')::int::boolean AS is_policy_locked,
    (item->>'reserve_stock')::int::boolean AS reserve_stock,
    (item->>'grant_commission')::int::boolean AS grant_commission,
    (item->>'delivered_by_supplier')::int::boolean AS delivered_by_supplier,
    (item->>'ensure_delivery_based_on_produced_serial_no')::int::boolean AS ensure_delivery_based_on_produced_serial_no,
    (item->>'page_break')::int::boolean AS page_break,
    
    -- Dates & Timestamps
    (item->>'transaction_date')::date AS transaction_date,
    (item->>'creation')::timestamp AS created_at,
    (item->>'modified')::timestamp AS updated_at,
    
    -- Audit & Internal
    item->>'owner' AS owner,
    item->>'modified_by' AS modified_by,
    (item->>'company_total_stock')::numeric AS company_total_stock,
    (item->>'production_plan_qty')::numeric AS production_plan_qty,
    
    -- DLT Metadata (get from parent table)
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM unnested_items