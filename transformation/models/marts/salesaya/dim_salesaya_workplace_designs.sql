{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    design_id                                                            AS id,
    design_code,
    design_code_legacy                                                   AS code,
    erp_code,
    backup_code,
    gender,
    design_type,
    wedding_ring_id,
    collections_id,
    ring_band_type,
    ring_band_style,
    ring_head_style,
    diamond_holder,
    _4view                                                                AS "4view"
FROM {{ ref('stg_nocodb__designs') }}
