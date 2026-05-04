{{ config(
    materialized='view',
    schema='staging'
) }}

WITH latest_campaigns AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id 
            ORDER BY updated_time DESC, _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('facebook_marketing', 'campaigns') }}
)
SELECT 
    id AS campaign_id,
    account_id,
    name AS campaign_name,
    status AS campaign_status,
    effective_status,
    objective,
    
    split_part(name, '_', 1) AS fx_campaign_region,
    split_part(name, '_', 2) AS fx_campaign_goal,
    split_part(name, '_', 3) AS fx_campaign_fanpage,
    split_part(name, '_', 4) AS fx_campaign_segment,
    split_part(name, '_', 5) AS fx_campaign_categories,

    daily_budget / 100.0 AS daily_budget,
    lifetime_budget / 100.0 AS lifetime_budget,
    spend_cap / 100.0 AS spend_cap,
    
    created_time,
    start_time,
    stop_time,
    updated_time AS fb_updated_time,
    _airbyte_extracted_at AS staging_updated_at

FROM latest_campaigns
WHERE row_num = 1
