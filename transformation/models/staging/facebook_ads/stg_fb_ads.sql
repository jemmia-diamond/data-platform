{{ config(
    materialized='view',
    schema='staging'
) }}

WITH latest_ads AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id 
            ORDER BY updated_time DESC, _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('facebook_marketing', 'ads') }}
)
SELECT 
    id AS ad_id,
    adset_id,
    campaign_id,
    account_id,
    name AS ad_name,
    status AS ad_status,
    effective_status,
    
    split_part(name, '_', 1) AS fx_ads_goal,
    split_part(name, '_', 2) AS fx_ads_segment,
    split_part(name, '_', 3) AS fx_ads_categories,
    split_part(name, '_', 4) AS fx_ads_product_type,

    (targeting ->> 'age_min')::int AS target_age_min,
    (targeting ->> 'age_max')::int AS target_age_max,
    targeting -> 'custom_audiences' AS custom_audiences_list, 
        
    creative ->> 'id' AS creative_id,

    tracking_specs AS ad_tracking_specs,
    conversion_specs AS ad_conversion_specs,

    created_time,
    updated_time AS fb_updated_time,
    _airbyte_extracted_at AS staging_updated_at

FROM latest_ads
WHERE row_num = 1
