{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS order_id,
    number::bigint AS number,
    order_number,
    name AS order_name,
    created_at::timestamp AS created_at,
    updated_at::timestamp AS updated_at,
    cancelled_at::timestamp AS cancelled_at,
    confirmed_at::timestamp AS confirmed_at,
    
    -- Statuses
    financial_status,
    fulfillment_status,
    closed_status,
    cancelled_status,
    confirmed_status,
    order_processing_status,
    cancel_reason,
    
    -- Payment & Channel
    gateway_code,
    gateway AS gateway_name,
    source_name AS channel,
    source,
    currency,
    
    -- Revenue metrics
    subtotal_price::numeric AS subtotal_price,
    total_price::numeric AS total_price,
    total_discounts::numeric AS total_discounts,
    total_tax::numeric AS total_tax,
    total_line_items_price::numeric AS total_line_items_price,
    
    -- Customer & Staff
    (customer->>'id')::bigint AS customer_id,
    user_id::bigint AS staff_user_id,
    contact_email,
    email,
    note,
    tags,
    
    -- Locations
    location_id::bigint AS location_id,
    location_name,
    assigned_location_id::bigint AS assigned_location_id,
    assigned_location_name,
    assigned_location_at::timestamp AS assigned_location_at,
    
    -- Shipping Info
    shipping_address->>'name' AS shipping_name,
    shipping_address->>'phone' AS shipping_phone,
    shipping_address->>'address1' AS shipping_address1,
    shipping_address->>'ward' AS shipping_ward,
    shipping_address->>'district' AS shipping_district,
    shipping_address->>'province' AS shipping_province,
    shipping_address->>'country' AS shipping_country,
    
    -- Billing Info
    billing_address->>'name' AS billing_name,
    billing_address->>'phone' AS billing_phone,
    billing_address->>'address1' AS billing_address1,
    billing_address->>'ward' AS billing_ward,
    billing_address->>'district' AS billing_district,
    billing_address->>'province' AS billing_province,
    
    -- UTM / Tracking
    utm_source,
    utm_medium,
    utm_campaign,
    utm_term,
    utm_content,
    referring_site,
    landing_site,
    landing_site_ref,
    
    -- Additional Metrics & Flags
    buyer_accepts_marketing,
    total_weight,
    taxes_included,
    token,
    cart_token,
    checkout_token,
    confirm_user::bigint AS confirm_user,
    risk_level,
    
    -- Unstructured / Complex JSON fields (Kept as JSON for downstream usage)
    client_details,
    discount_codes,
    shipping_lines,
    refunds,
    note_attributes,
    
    -- Chained reference fields (Used for recursive CTE lineage)
    (prev_order_id)::bigint AS prev_order_id,
    prev_order_number,
    (prev_order_date)::timestamp AS prev_order_date,
    
    (ref_order_id)::bigint AS ref_order_id,
    ref_order_number,
    (ref_order_date)::timestamp AS ref_order_date,
    
    -- Extract latest info from nested arrays
    transactions->0->>'gateway' AS latest_payment_gateway,
    transactions->0->>'kind' AS latest_transaction_kind,
    (transactions->0->>'amount')::numeric AS latest_transaction_amount,
    
    fulfillments->0->>'status' AS latest_fulfillment_status,
    fulfillments->0->>'carrier_status_name' AS latest_carrier_status,
    fulfillments->0->>'carrier_cod_status_name' AS latest_cod_status,
    (fulfillments->0->>'delivered_date')::timestamp AS latest_delivered_date,
    (fulfillments->0->>'cod_amount')::numeric AS latest_cod_amount,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'orders') }}
