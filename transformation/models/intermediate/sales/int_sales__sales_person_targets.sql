{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_sales_persons as (
    select sales_person_id, targets from {{ ref('stg_erpnext__sales_persons') }}
),

flattened_targets as (
    select
        sales_person_id,
        jsonb_array_elements(targets) as target_item
    from staging_sales_persons
    where targets is not null
),

extracted_periods as (
    select
        target_item ->> 'name' as sales_target_id,
        sales_person_id,
        target_item ->> 'fiscal_year' as fiscal_year,
        target_item ->> 'distribution_id' as target_period_name, -- e.g., "Sales Target 2026/01"
        right(target_item ->> 'distribution_id', 2)::integer as target_month,
        
        -- Form a standard YYYY-MM string for date conversion
        (target_item ->> 'fiscal_year') || '-' || right(target_item ->> 'distribution_id', 2) as year_month_str,

        (target_item ->> 'target_amount')::numeric as target_amount,
        (target_item ->> 'target_qty')::numeric as target_quantity,
        
        (target_item ->> 'target_lead_received')::integer as target_lead_received,
        (target_item ->> 'target_qualified_leads')::integer as target_qualified_leads,
        (target_item ->> 'target_qualified_to_orders')::integer as target_qualified_to_orders,
        (target_item ->> 'target_previous_month_qualified')::integer as target_previous_month_qualified,
        
        target_item ->> 'owner' as target_owner,
        (target_item ->> 'creation')::timestamp without time zone as created_at,
        (target_item ->> 'modified')::timestamp without time zone as updated_at
    from flattened_targets
),

calculated_dates as (
    select
        *,
        -- Generate the first day of the target month
        to_date(year_month_str, 'YYYY-MM') as valid_from
    from extracted_periods
)

select
    -- 1. Identity & Keys
    sales_target_id,
    sales_person_id,

    -- 2. Temporal & Validity Periods (From - To)
    fiscal_year,
    target_period_name,
    target_month,
    valid_from,
    -- Generate the last day of the target month by adding 1 month and subtracting 1 day
    (valid_from + interval '1 month' - interval '1 day')::date as valid_to,

    -- 3. Financial KPIs
    target_amount,
    target_quantity,
    
    -- 4. Operational KPIs
    target_lead_received,
    target_qualified_leads,
    target_qualified_to_orders,
    target_previous_month_qualified,
    
    -- 5. Audit Metadata
    target_owner,
    created_at,
    updated_at

from calculated_dates