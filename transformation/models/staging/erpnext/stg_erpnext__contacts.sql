{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS contact_id,
    
    -- Basic Profile
    first_name,
    middle_name,
    last_name,
    full_name,
    salutation,
    gender,
    image,
    
    -- Contact Information
    email_id AS email,
    COALESCE(phone, mobile_no) AS phone,
    phone AS phone_number,
    mobile_no AS mobile_number,
    address,
    
    -- Status & Types
    status,
    is_primary_contact::int::boolean AS is_primary_contact,
    is_billing_contact::int::boolean AS is_billing_contact,
    
    -- Ownership & Integration
    user AS mapped_user,
    lead_owner,
    haravan_customer_id,
    custom_uuid,
    
    -- Social & Omni-channel (Pancake)
    pancake_customer_id,
    pancake_page_id,
    pancake_conversation_id,
    can_inbox::int::boolean AS can_inbox,
    is_replied::int::boolean AS is_replied,
    pancake_inserted_at::timestamp AS pancake_inserted_at,
    pancake_updated_at::timestamp AS pancake_updated_at,
    last_message_time::timestamp AS last_message_time,
    last_summarize_time::timestamp AS last_summarize_time,
    thread_id,
    message_id,
    message_time::timestamp AS message_time,
    
    -- Call Center (Stringee)
    stringee_id,
    stringee_from_number,
    stringee_to_number,
    stringee_start_time::timestamp AS stringee_start_time,
    stringee_end_time::timestamp AS stringee_end_time,
    stringee_from_internal::int::boolean AS stringee_from_internal,
    stringee_to_internal::int::boolean AS stringee_to_internal,
    stringee_recorded::int::boolean AS stringee_recorded,
    video_call::int::boolean AS video_call,
    
    -- Google Contacts Sync
    sync_with_google_contacts::int::boolean AS sync_with_google_contacts,
    pulled_from_google_contacts::int::boolean AS pulled_from_google_contacts,
    
    -- Marketing & Tracking (UTM / Ad IDs)
    source,
    source_group,
    source_name,
    first_source,
    last_source,
    utm_source,
    utm_medium,
    utm_campaign,
    utm_term,
    utm_content,
    ad_ids,
    gclid,
    gad_source,
    gad_campaignid,
    gbraid,
    fbclid,
    ttclid,
    gcl_au_id,
    ga_client_id,
    fb_client_id,
    ladi_client_id,
    first_ad_param,
    last_ad_param,
    
    -- Marketing Forms & Web Tracking
    form_id,
    form_name,
    ladi_form_id,
    form_inserted_at::timestamp AS form_inserted_at,
    form_updated_at::timestamp AS form_updated_at,
    origin_url_page,
    url_page,
    page_url,
    conversion_url,
    variant_url,
    variant_content,
    referrer,
    gtm_link,
    gtm_location,
    ip,
    remote_ip,
    user_agent,
    unsubscribed::int::boolean AS is_unsubscribed,
    
    -- Flags & Configuration
    docstatus::int AS docstatus,
    idx::int AS idx,
    
    -- Timestamps
    inserted_at::timestamp AS inserted_at,
    updated_at::timestamp AS contact_updated_at,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by,
    
    -- Frappe Internal & Metadata
    _assign,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'contacts') }}
WHERE name NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Contact'
      AND (restored IS NULL OR restored = 0)
)
