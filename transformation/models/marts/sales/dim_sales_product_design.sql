{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_dsp_design_id ON {{ this }} (design_id)",
        "CREATE INDEX IF NOT EXISTS idx_dsp_design_code ON {{ this }} (design_code)"
    ]
) }}

select *
from {{ ref('int_catalog__designs')}}