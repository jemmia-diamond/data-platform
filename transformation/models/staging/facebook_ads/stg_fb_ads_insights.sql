{{ config(
    materialized='view',
    schema='staging'
) }}

WITH deduped_insights AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY ad_id, date_start 
            ORDER BY _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('facebook_marketing', 'ads_insights') }}
),
flattened_actions AS (
SELECT
	ad_id,
	date_start,
	SUM(
		CASE
			WHEN act ->> 'action_type' = 'onsite_conversion.messaging_conversation_started_7d' THEN (act ->> 'value')::numeric
			ELSE 0
		END
	) AS messenger_convo_started,
	SUM(
		CASE
			WHEN act ->> 'action_type' = 'lead' THEN (act ->> 'value')::numeric
			ELSE 0
		END
	) AS leads,
	SUM(
		CASE
			WHEN act ->> 'action_type' = 'link_click' THEN (act ->> 'value')::numeric
			ELSE 0
		END
	) AS link_clicks,
	SUM(
		CASE
			WHEN act ->> 'action_type' = 'post_engagement' THEN (act ->> 'value')::numeric
			ELSE 0
		END
	) AS post_engagement
FROM
	deduped_insights,
	LATERAL jsonb_array_elements(actions) AS act
WHERE
	row_num = 1
GROUP BY
	1,
	2
)
SELECT 
    md5(concat(d.ad_id, '_', d.date_start)) AS fact_fb_ads_key,
    d.ad_id,
    d.adset_id,
    d.campaign_id,
    d.account_id,
    d.date_start AS report_date,
    
    d.spend,
    d.clicks,
    d.impressions,
    d.reach,
    d.frequency,
    
    COALESCE(f.messenger_convo_started, 0) AS messenger_convo_started,
    COALESCE(f.leads, 0) AS leads,
    COALESCE(f.link_clicks, 0) AS link_clicks,
    COALESCE(f.post_engagement, 0) AS post_engagement,

    d.quality_ranking,
    d.conversion_rate_ranking,
    d.engagement_rate_ranking,

    d._airbyte_extracted_at AS staging_updated_at

FROM deduped_insights d
LEFT JOIN flattened_actions f 
    ON d.ad_id = f.ad_id AND d.date_start = f.date_start
WHERE d.row_num = 1
