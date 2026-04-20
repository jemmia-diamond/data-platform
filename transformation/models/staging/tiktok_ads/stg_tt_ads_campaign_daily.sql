{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * 
    FROM {{ source('tiktok_marketing', 'campaigns_reports_daily') }}
),

tiktok_flattened AS (
    SELECT 
        COALESCE((dimensions->>'campaign_id')::int8, campaign_id) AS campaign_id,
        stat_time_day::date AS report_date,
        advertiser_id,
        metrics->>'campaign_name' AS campaign_name,
        CAST(COALESCE(metrics->>'spend', '0') AS NUMERIC) AS spend,
        CAST(COALESCE(metrics->>'clicks', '0') AS int8) AS clicks,
        CAST(COALESCE(metrics->>'impressions', '0') AS int8) AS impressions,
        CAST(COALESCE(metrics->>'reach', '0') AS int8) AS reach,
        CAST(COALESCE(metrics->>'likes', '0') AS int8) AS likes,
        CAST(COALESCE(metrics->>'follows', '0') AS int8) AS follows,
        CAST(COALESCE(metrics->>'video_views_p100', '0') AS int8) AS video_completions,
        _airbyte_extracted_at
    FROM source
),

deduped_tiktok AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id, report_date 
            ORDER BY _airbyte_extracted_at DESC
        ) AS row_num
    FROM tiktok_flattened
)

SELECT 
    md5(concat(campaign_id, '_', report_date)) AS tiktok_daily_id,
    campaign_id,
    campaign_name,
    report_date,
    advertiser_id,
    spend,
    clicks,
    impressions,
    reach,
    likes,
    follows,
    video_completions,
    CASE WHEN impressions > 0 THEN (clicks::float / impressions) * 100 ELSE 0 END AS ctr,
    CASE WHEN clicks > 0 THEN spend / clicks ELSE 0 END AS cpc
FROM deduped_tiktok
WHERE row_num = 1
