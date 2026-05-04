{{ config(
    materialized='view',
    schema='staging'
) }}

WITH latest_network_records AS (
    SELECT 
        campaign_id,
        campaign_name,
        segments_date AS report_date,
        segments_hour,
        campaign_status,
        campaign_advertising_channel_type AS channel_type,
        metrics_cost_micros,
        metrics_clicks,
        metrics_impressions,
        metrics_conversions,
        metrics_conversions_value,
        campaign_budget_amount_micros,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id, segments_date, segments_hour, segments_ad_network_type 
            ORDER BY _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('google_ads', 'campaign') }}
),
aggregated_daily AS (
    SELECT 
        campaign_id,
        MAX(campaign_name) AS campaign_name,
        report_date,
        segments_hour,
        MAX(campaign_status) AS campaign_status,
        MAX(channel_type) AS channel_type,
        
        SUM(CAST(metrics_cost_micros AS NUMERIC) / 1000000.0) AS spend,
        SUM(metrics_clicks) AS clicks,
        SUM(metrics_impressions) AS impressions,
        SUM(metrics_conversions) AS conversions,
        SUM(metrics_conversions_value) AS conversion_value,
        
        MAX(CAST(campaign_budget_amount_micros AS NUMERIC) / 1000000.0) AS daily_budget
    FROM latest_network_records
    WHERE row_num = 1
    GROUP BY 1, 3, 4
)
SELECT 
    md5(concat(campaign_id, '_', report_date, '_', segments_hour)) AS google_daily_id,
    campaign_id,
    campaign_name,
    report_date,
    segments_hour,
    campaign_status,
    channel_type,
    spend,
    clicks,
    impressions,
    conversions,
    conversion_value,
    daily_budget,
    
    CASE WHEN impressions > 0 THEN (clicks::float / impressions) * 100 ELSE 0 END AS ctr,
    CASE WHEN clicks > 0 THEN spend / clicks ELSE 0 END AS cpc,
    CASE WHEN spend > 0 THEN conversion_value / spend ELSE 0 END AS roas
FROM aggregated_daily
