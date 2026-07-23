{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Diamond lifecycle history — one row per diamond, with an ordered JSON array of its
-- history events (date, stage, status, errors, note, attachment). Built by joining the
-- diamonds_history events to the diamonds_history_diamonds bridge table.
-- Grain: 1 row per diamond.
SELECT
    hd.diamond_id,
    json_agg(
        json_build_object(
            'date', h.history_date,
            'stage', h.stage,
            'status', h.status,
            'errors', h.errors,
            'note', h.note,
            'attachment', h.attachment
        )
        ORDER BY h.history_date DESC NULLS LAST, h.diamond_history_id DESC
    ) FILTER (WHERE h.diamond_history_id IS NOT NULL) AS history
FROM {{ ref('stg_nocodb__diamonds_history_diamonds') }} hd
LEFT JOIN {{ ref('stg_nocodb__diamonds_history') }} h
    ON h.diamond_history_id = hd.diamond_history_id
GROUP BY hd.diamond_id
