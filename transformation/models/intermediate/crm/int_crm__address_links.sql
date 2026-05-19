{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_address as (
    select address_id, dynamic_links from {{ ref('stg_erpnext__addresses') }}
),

flattened_links as (
    select
        address_id,
        jsonb_array_elements(dynamic_links) as link_item
    from staging_address
    where dynamic_links is not null
)

select
    -- 1. Identity & Deterministic Keys
    link_item ->> 'name' as address_link_id,
    
    -- 2. Core Info
    link_item ->> 'link_doctype' as link_doctype, -- 'Customer', 'Lead', 'Supplier'...
    link_item ->> 'link_name' as link_id,    
    link_item ->> 'link_title' as link_title,
    (link_item ->> 'idx')::integer as link_priority_idx,
    (link_item ->> 'creation')::timestamp without time zone as link_created_at

from flattened_links