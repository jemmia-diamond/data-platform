{{ config(
    materialized='view',
    schema='staging'
) }}

WITH deduped_daily AS (
    SELECT 
        campaign_id,
        campaign_name,
        account_id,
        date_start AS report_date,
        CAST(spend AS NUMERIC) AS spend,
        clicks,
        impressions,
        cpc AS fb_reported_cpc,
        ctr AS fb_reported_ctr,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id, date_start 
            ORDER BY _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('facebook_marketing', 'custom_campaign_daily') }}
)
SELECT 
    md5(concat(campaign_id, '_', report_date)) AS daily_id,
    campaign_id,
    campaign_name,
    account_id,
    report_date,
    spend,
    clicks,
    impressions,
    CASE WHEN clicks > 0 THEN spend / clicks ELSE 0 END AS calculated_cpc,
    CASE WHEN impressions > 0 THEN (clicks::float / impressions) * 100 ELSE 0 END AS calculated_ctr
FROM deduped_daily
WHERE row_num = 1
