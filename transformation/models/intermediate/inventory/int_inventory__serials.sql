{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    vs.serial_id                                                          AS item_id,
    vs.serial_number,
    vs.variant_id,
    vs.printing_batch,
    vs.encode_barcode,
    vs.final_encoded_barcode,
    vs.product_name                                                       AS item_name,
    vs.displayed_title,
    vs.design_code,
    vs.ma_thiet_ke_cu                                                     AS legacy_code,
    vs.ma_erp,
    vs.haravan_product_type                                               AS category,
    vs.stock_at                                                           AS stock_location,
    vs.fulfillment_status_value,
    vs.gold_weight,
    vs.diamond_weight,
    vs.actual_gold_price,
    vs.actual_melee_price,
    vs.actual_labor_cost,
    vs.price,
    vs.cogs,
    vs.quantity,
    vs.barcode,
    vs.sku,
    vs.supplier,
    vs.is_have_invoice,
    vs.order_id,
    vs.stock_id,
    vs.order_on,
    vs.order_reference,
    vs.last_rfid_scan_time,
    vs.arrival_date,
    vs.supplier_invoice,
    vs.address_invoice,
    vs.policy,
    vs.created_at,
    vs.updated_at,

    -- Salesaya enrichment: physical storage dimensions (from variant_serials)
    vs.storage_size_1,
    vs.storage_size_2

FROM {{ ref('stg_nocodb__variant_serials') }} vs
