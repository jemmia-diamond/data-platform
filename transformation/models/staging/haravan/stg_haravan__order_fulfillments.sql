{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint AS order_id,
        jsonb_array_elements(fulfillments) AS fulfillment
    FROM {{ source('haravan', 'orders') }}
    WHERE fulfillments IS NOT NULL AND jsonb_typeof(fulfillments) = 'array'
)

SELECT
    (fulfillment->>'id')::bigint AS fulfillment_id,
    order_id,
    fulfillment->>'status' AS fulfillment_status,
    fulfillment->>'tracking_company' AS tracking_company,
    fulfillment->>'tracking_number' AS tracking_number,
    
    -- Ngày tháng quan trọng của vận đơn
    (fulfillment->>'created_at')::timestamp AS created_at,
    (fulfillment->>'ready_to_pick_date')::timestamp AS ready_to_pick_date,
    (fulfillment->>'delivered_date')::timestamp AS delivered_date,
    
    -- Trạng thái đơn vị vận chuyển
    fulfillment->>'carrier_status_name' AS carrier_status_name,
    fulfillment->>'carrier_cod_status_name' AS carrier_cod_status_name,
    
    -- Tiền thu hộ COD
    (fulfillment->>'cod_amount')::numeric AS cod_amount,
    (fulfillment->>'real_shipping_fee')::numeric AS real_shipping_fee

FROM unnested
