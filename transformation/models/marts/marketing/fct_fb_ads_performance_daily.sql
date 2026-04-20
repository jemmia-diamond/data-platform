{{ config(
    materialized='materialized_view',
    schema='analytics'
) }}

SELECT 
    -- 1. Identifiers and Time
    f.fact_fb_ads_key,
    f.report_date,
    f.ad_id,
    f.adset_id,
    f.campaign_id,
    f.account_id,

    -- 2. Campaign Information
    c.fx_campaign_region,
    c.fx_campaign_goal,
    c.fx_campaign_fanpage,
    c.fx_campaign_segment,
    c.fx_campaign_categories,
    c.campaign_status,
    c.campaign_name,

    -- 3. Adset Information
    s.fx_adset_type,
    s.fx_adset_audience_name,
    s.fx_adset_region,
    s.fx_adset_gender,
    s.fx_adset_age_range,
    s.adset_name,

    -- 4. Ad Information
    a.fx_ads_goal,
    a.fx_ads_segment,
    a.fx_ads_categories,
    a.fx_ads_product_type,
    a.ad_name,
    a.ad_status,
    CASE 
        WHEN a.target_age_min IS NULL OR a.target_age_max IS NULL THEN 'Not specified'
        ELSE concat(a.target_age_min, ' - ', a.target_age_max)
    END AS fx_adset_age_range_targeting,

    -- 5. Performance Metrics
    f.spend,
    f.clicks,
    f.impressions,
    f.reach,
    f.leads,
    f.messenger_convo_started AS conversation_started,
    f.post_engagement,

    -- 6. Calculated Metrics for BI
    CASE WHEN f.impressions > 0 THEN (f.clicks::float / f.impressions) * 100 ELSE 0 END AS ctr,
    CASE WHEN f.clicks > 0 THEN f.spend / f.clicks ELSE 0 END AS cpc,
    CASE WHEN f.leads > 0 THEN f.spend / f.leads ELSE 0 END AS cost_per_lead,
    CASE WHEN f.messenger_convo_started > 0 THEN f.spend / f.messenger_convo_started ELSE 0 END AS cost_per_messaging

FROM {{ ref('stg_fb_ads_insights') }} f
LEFT JOIN {{ ref('stg_fb_ads') }} a ON f.ad_id = a.ad_id
LEFT JOIN {{ ref('stg_fb_adsets') }} s ON f.adset_id = s.adset_id
LEFT JOIN {{ ref('stg_fb_campaigns') }} c ON f.campaign_id = c.campaign_id
