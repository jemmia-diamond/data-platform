{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_contacts as (
    select * from {{ ref('stg_erpnext__contacts') }}
),

extracted_contacts as (
    select
        -- 1. Identity & System Keys
        contact_id,
        CASE 
            WHEN dynamic_links #>> '{0, link_doctype}' = 'Lead' 
            THEN dynamic_links #>> '{0, link_name}'
            ELSE NULL 
        END AS primary_lead_id,
        ad_ids,

        -- 3. Core Information
        full_name,
        salutation,
        gender,
        email,
        phone,
        phone_number,
        mobile_number,
        address,
        status,
        ad_ids ->> 0 AS first_ad_id,
        CASE 
            WHEN ad_ids -> 1 IS NOT NULL 
            THEN ad_ids ->> -1 
            ELSE NULL 
        END AS last_ad_id,
        
        -- 4. Flags
        is_primary_contact,
        is_billing_contact,
        
        -- 5. Omni-channel Cross IDs (Pancake, Haravan, Stringee...)
        pancake_customer_id,
        pancake_page_id,
        pancake_conversation_id,
        haravan_customer_id,
        stringee_id,
        
        -- 6. Marketing UTMs & Attribution
        source,
        source_group,
        source_name,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_term,
        utm_content,
        gclid,
        fbclid,
        
        -- 7. Audit Timestamps
        created_at,
        updated_at,
        contact_updated_at,
        _db_updated_at

    from staging_contacts
),

-- only get the last ad_ids list of customer (based on updated_at)
add_rn_ad_ids_customer as (
	select *,
		ROW_NUMBER() OVER (
               PARTITION BY pancake_customer_id
               ORDER BY updated_at desc
           ) rn
	from extracted_contacts
),

get_last_ad_ids_customer as (
	select *
	from add_rn_ad_ids_customer
	where rn = 1
)

select * from get_last_ad_ids_customer