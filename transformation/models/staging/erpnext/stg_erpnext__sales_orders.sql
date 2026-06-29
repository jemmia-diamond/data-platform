{{ config(
    materialized='view',
    schema='staging'
) }}

with stg_erp_order as (
    SELECT
        -- Primary Key
        name AS sales_order_id,

        -- Identity & Profile
        title AS order_title,
        order_number,
        order_type,
        source_name,
        company,
        naming_series,
        order_policies,
        customer AS customer_id,
        customer_name,
        customer_type,
        gender,
        birth_date::date AS birth_date,

        -- Contact Information
        contact_person,
        contact_display,
        COALESCE(contact_phone, contact_mobile) AS phone,
        contact_email,

        -- Customer Identity Documents
        customer_personal_id,
        customer_passport_id,
        custom_passport_id,

        -- Locations & Addresses
        customer_address,
        billing_address,
        delivery_location,
        deposit_location,

        -- Statuses
        status,
        delivery_status,
        billing_status,
        financial_status,
        fulfillment_status,
        carrier_status,
        advance_payment_status,
        cancelled_status,
        return_type,

        -- Currency & Conversion
        docstatus::int AS docstatus,
        currency,
        order_currency,
        price_list_currency,
        party_account_currency,
        conversion_rate::numeric AS conversion_rate,
        plc_conversion_rate::numeric AS plc_conversion_rate,

        -- Financial Metrics (Local Currency)
        base_total::numeric AS base_total,
        base_net_total::numeric AS base_net_total,
        base_grand_total::numeric AS base_grand_total,
        base_total_taxes_and_charges::numeric AS base_total_taxes_and_charges,
        base_discount_amount::numeric AS base_discount_amount,
        base_rounded_total::numeric AS base_rounded_total,
        base_rounding_adjustment::numeric AS base_rounding_adjustment,
        base_in_words,

        -- Financial Metrics (Transaction Currency)
        total::numeric AS total,
        net_total::numeric AS net_total,
        grand_total::numeric AS grand_total,
        total_amount::numeric AS total_amount,
        total_taxes_and_charges::numeric AS total_taxes_and_charges,
        discount_amount::numeric AS discount_amount,
        additional_discount_percentage::numeric AS additional_discount_percentage,
        apply_discount_on,
        rounded_total::numeric AS rounded_total,
        rounding_adjustment::numeric AS rounding_adjustment,
        in_words,

        -- Quantities & Weights
        total_qty::numeric AS total_qty,
        total_net_weight::numeric AS total_net_weight,

        -- Payment & Balance Info
        paid_amount::numeric AS paid_amount,
        advance_paid::numeric AS advance_paid,
        balance::numeric AS balance,
        balance_payment::numeric AS balance_payment,
        balance_group_payment::numeric AS balance_group_payment,
        deposit_amount::numeric AS deposit_amount,
        deposit_method,
        total_allocated_payment::numeric AS total_allocated_payment,
        total_allocated_group_payment::numeric AS total_allocated_group_payment,
        return_amount::numeric AS return_amount,

        -- Commissions & Loyalty
        amount_eligible_for_commission::numeric AS amount_eligible_for_commission,
        commission_base_amount::numeric AS commission_base_amount,
        commission_rate::numeric AS commission_rate,
        total_commission::numeric AS total_commission,
        loyalty_amount::numeric AS loyalty_amount,
        loyalty_points::int AS loyalty_points,

        -- Picking & Delivery Progress
        per_billed::numeric AS per_billed,
        per_delivered::numeric AS per_delivered,
        per_picked::numeric AS per_picked,
        tracking_number,

        -- Promotion Code
         {{ safe_cast_jsonb('sales_order_promotions') }} as sales_order_promotions,

        -- Child Tables
        {{ safe_cast_jsonb('payment_entry_references') }} as payment_entry_references,
        {{ safe_cast_jsonb('product_categories') }} as product_categories,
        {{ safe_cast_jsonb('sales_order_policies') }} as sales_order_policies,
        {{ safe_cast_jsonb('sales_order_purposes') }} as sales_order_purposes,
        {{ safe_cast_jsonb('sales_teams') }} as sales_teams,
        {{ safe_cast_jsonb('order_and_debt_tracking') }} as order_and_debt_tracking,

        -- Flags
        is_internal_customer::int::boolean AS is_internal_customer,
        is_split_order::int::boolean AS is_split_order,
        is_subcontracted::int::boolean AS is_subcontracted,
        disable_rounded_total::int::boolean AS disable_rounded_total,
        group_same_items::int::boolean AS group_same_items,
        has_unit_price_items::int::boolean AS has_unit_price_items,
        ignore_default_payment_terms_template::int::boolean AS ignore_default_payment_terms_template,
        ignore_pricing_rule::int::boolean AS ignore_pricing_rule,
        reserve_stock::int::boolean AS reserve_stock,
        skip_delivery_note::int::boolean AS skip_delivery_note,

        -- Grouping & Logic
        split_order_group,
        split_order_group_name,
        split_reason,
        primary_sales_person,
        selling_price_list,
        tax_category,
        language,
        letter_head,
        owner,
        modified_by,

        -- Haravan Integration (Omnichannel)
        haravan_order_id,
        haravan_ref_order_id,
        haravan_coupon_code,
        haravan_created_at::timestamp AS haravan_created_at,

        -- Dates & Timestamps
        transaction_date::date AS transaction_date,
        transaction_time,
        real_order_date::date AS real_order_date,
        expected_delivery_date::date AS expected_delivery_date,
        expected_payment_date::date AS expected_payment_date,
        consultation_date::date AS consultation_date,
        date_of_issuance::date AS date_of_issuance,
        place_of_issuance,
        fulfillment_completion_date::timestamp AS fulfillment_completion_date,
        creation::timestamp AS created_at,
        modified::timestamp AS updated_at,

        -- Frappe Internal & DLT Metadata
        {{ safe_cast_jsonb('_seen') }} as _seen,
        {{ safe_cast_jsonb('_comments') }} as _comments,
        {{ safe_cast_jsonb('_assign') }} as _assign,
        _liked_by,
        _db_updated_at::timestamp AS _db_updated_at,
        _dlt_load_id,
        _dlt_id

    FROM {{ source('erpnext', 'sales_orders') }}
    WHERE NOT EXISTS (
        SELECT 1
        FROM {{ source('erpnext', 'deleted_documents') }} dd
        WHERE dd.deleted_doctype = 'Sales Order'
          AND (dd.restored IS NULL OR dd.restored = 0)
          AND dd.deleted_name = name
          AND dd.data::jsonb->>'order_number' = order_number
    )
),
sales_order_exploded_promotions as (
	SELECT
		order_number,
	    jsonb_agg(x->>'promotion') AS order_promotion
	FROM {{ source('erpnext', 'sales_orders') }} so
	CROSS JOIN LATERAL jsonb_array_elements(
	    so.sales_order_promotions::jsonb
	) x
	group by 1
)
select
    o.*,
    p.order_promotion
from stg_erp_order o
left join sales_order_exploded_promotions p on o.order_number = p.order_number

