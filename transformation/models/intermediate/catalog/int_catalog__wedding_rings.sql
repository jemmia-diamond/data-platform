{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Wedding ring reference — source of truth for wedding ring identities.
-- Grain: 1 row per wedding ring.
SELECT
    wedding_ring_id,
    description,
    ecom_title,
    _db_updated_at
FROM {{ ref('stg_nocodb__wedding_rings') }}
