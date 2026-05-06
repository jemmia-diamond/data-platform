{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key & Parent Link
    name AS sales_order_item_id,
    parent AS sales_order_id,
    parenttype AS parent_type,
    parentfield AS parent_field,
    idx::int AS line_item_idx,
    
    -- Item Identification
    sku,
    item_name,
    variant_title,
    barcode,
    image,
    
    -- Haravan Integration
    haravan_variant_id::bigint AS haravan_variant_id,
    
    -- Quantities
    qty::numeric AS qty,
    stock_qty::numeric AS stock_qty,
    ordered_qty::numeric AS ordered_qty,
    delivered_qty::numeric AS delivered_qty,
    picked_qty::numeric AS picked_qty,
    returned_qty::numeric AS returned_qty,
    actual_qty::numeric AS actual_qty,
    planned_qty::numeric AS planned_qty,
    produced_qty::numeric AS produced_qty,
    projected_qty::numeric AS projected_qty,
    requested_qty::numeric AS requested_qty,
    stock_reserved_qty::numeric AS stock_reserved_qty,
    subcontracted_qty::numeric AS subcontracted_qty,
    work_order_qty::numeric AS work_order_qty,
    fg_item_qty::numeric AS fg_item_qty,
    
    -- UOM & Conversions
    uom,
    stock_uom,
    conversion_factor::numeric AS conversion_factor,
    
    -- Financials (Transaction Currency)
    rate::numeric AS rate,
    amount::numeric AS amount,
    net_rate::numeric AS net_rate,
    net_amount::numeric AS net_amount,
    price_list_rate::numeric AS price_list_rate,
    discount_amount::numeric AS discount_amount,
    discount_percentage::numeric AS discount_percentage,
    distributed_discount_amount::numeric AS distributed_discount_amount,
    billed_amt::numeric AS billed_amt,
    rate_with_margin::numeric AS rate_with_margin,
    margin_rate_or_amount::numeric AS margin_rate_or_amount,
    margin_type,
    gross_profit::numeric AS gross_profit,
    valuation_rate::numeric AS valuation_rate,
    
    -- Financials (Base Currency)
    base_rate::numeric AS base_rate,
    base_amount::numeric AS base_amount,
    base_net_rate::numeric AS base_net_rate,
    base_net_amount::numeric AS base_net_amount,
    base_price_list_rate::numeric AS base_price_list_rate,
    base_rate_with_margin::numeric AS base_rate_with_margin,
    
    -- Product Specifics (Diamonds/Jewelry)
    serial_numbers,
    serial,
    diamond_details,
    product_details,
    weight_per_unit::numeric AS weight_per_unit,
    total_weight::numeric AS total_weight,
    weight_uom,
    
    -- Promotions & Pricing Rules
    promotion,
    promotion_1,
    promotion_2,
    promotion_3,
    promotion_4,
    promotion_5,
    new_promotions,
    pricing_rules,
    discount_rate,
    
    -- Status & Workflow
    docstatus::int AS docstatus,
    product_availability_status,
    type AS item_type,
    item_policy,
    item_tax_rate,
    cost_center,
    
    -- Blanket Orders
    against_blanket_order::int::boolean AS against_blanket_order,
    blanket_order_rate::numeric AS blanket_order_rate,
    
    -- Flags (Booleans)
    is_free_item::int::boolean AS is_free_item,
    is_stock_item::int::boolean AS is_stock_item,
    is_policy_locked::int::boolean AS is_policy_locked,
    reserve_stock::int::boolean AS reserve_stock,
    grant_commission::int::boolean AS grant_commission,
    delivered_by_supplier::int::boolean AS delivered_by_supplier,
    ensure_delivery_based_on_produced_serial_no::int::boolean AS ensure_delivery_based_on_produced_serial_no,
    page_break::int::boolean AS page_break,
    
    -- Dates & Timestamps
    transaction_date::date AS transaction_date,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    
    -- Audit & Internal
    owner,
    modified_by,
    company_total_stock::numeric AS company_total_stock,
    production_plan_qty::numeric AS production_plan_qty,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'sales_order_items') }}
WHERE parent NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Sales Order'
      AND (restored IS NULL OR restored = 0)
)
