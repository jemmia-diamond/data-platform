{{ config(
    materialized='materialized_view',
    schema='analytics'
) }}

WITH platform_list AS (
    SELECT 'Facebook' AS platform_name
    UNION SELECT 'Google'
    UNION SELECT 'TikTok'
),
date_platform_grid AS (
    SELECT 
        d.date_actual,
        p.platform_name
    FROM {{ ref('dim_dates') }} d
    CROSS JOIN platform_list p
    WHERE d.date_actual <= CURRENT_DATE 
      AND d.date_actual >= '2020-01-01'
),
union_metrics AS (
    SELECT report_date, 'Facebook' as platform_name, SUM(spend) as spend, SUM(clicks) as clicks, SUM(impressions) as impressions 
    FROM {{ ref('stg_fb_ads_custom_campaign_daily') }} GROUP BY 1, 2
    UNION ALL
    SELECT report_date, 'Google', SUM(spend), SUM(clicks), SUM(impressions) 
    FROM {{ ref('stg_gg_ads_campaign_daily') }} GROUP BY 1, 2
    UNION ALL
    -- Aggregate directly from TikTok data
    SELECT report_date, 'TikTok', SUM(spend), SUM(clicks), SUM(impressions) 
    FROM {{ ref('stg_tt_ads_campaign_daily') }} GROUP BY 1, 2
)
SELECT 
    grid.date_actual AS report_date,
    grid.platform_name,
    COALESCE(m.spend, 0) AS total_spend,
    COALESCE(m.clicks, 0) AS total_clicks,
    COALESCE(m.impressions, 0) AS total_impressions,
    md5(concat(grid.date_actual, '_', grid.platform_name)) AS marketing_perf_key
FROM date_platform_grid grid
LEFT JOIN union_metrics m 
    ON grid.date_actual = m.report_date 
    AND grid.platform_name = m.platform_name