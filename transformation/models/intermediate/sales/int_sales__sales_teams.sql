{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_orders as (
    select 
        sales_order_id, 
        sales_teams 
    from {{ ref('stg_erpnext__sales_orders') }}
),

flattened_teams as (
    select
        sales_order_id,
        -- Flatten the JSONB array into individual object rows
        jsonb_array_elements(sales_teams) as team_item
    from staging_orders
    where sales_teams is not null 
      and sales_teams != '[]'::jsonb
)

select
    -- 1. Identity & Keys (Using the native JSON 'name' attribute directly as the Primary Key)
    team_item ->> 'name' as order_sales_team_id,

    -- 2. Foreign Keys
    sales_order_id as erp_sales_order_id,
    team_item ->> 'sales_person' as sales_person_id,

    -- 3. Allocation & Financial Metrics
    (team_item ->> 'allocated_percentage')::numeric as allocated_percentage,
    (team_item ->> 'allocated_amount')::numeric as allocated_amount,
    (team_item ->> 'incentives')::numeric as incentives_amount,
    
    -- 4. Attribution Helpers
    (team_item ->> 'merator')::integer as split_numerator,
    (team_item ->> 'denominator')::integer as split_denominator,

    -- 5. Audit Metadata
    team_item ->> 'owner' as record_owner,
    (team_item ->> 'creation')::timestamp without time zone as created_at,
    (team_item ->> 'modified')::timestamp without time zone as updated_at

from flattened_teams
-- Safety filter: Ensure we only keep records that actually have a valid internal sales person ID
where team_item ->> 'sales_person' is not null