{{ config(
    materialized='view',
    schema='staging'
) }}

-- GIA report data — per-report grading attributes plus the PDF URL and encrypted report number.
-- Sourced from the gia_edu system (raw_gia_edu.report_no_data, a managed non-dlt table). Used by the
-- salesaya diamond mart to surface gia_pdf_url and encrypted_report_no.
-- Deduplicated by report_no (the source carries duplicate report rows; latest by updated_at wins).
-- Grain: 1 row per report_no.
SELECT DISTINCT ON (report_no)
    id::bigint                                                  AS report_data_id,
    report_no,
    report_type,
    report_dt,
    shape,
    measurements,
    weight,
    color_grade,
    clarity_grade,
    cut_grade,
    depth,
    table_size,
    crown_angle,
    crown_height,
    pavilion_angle,
    pavilion_depth,
    star_length,
    lower_half,
    girdle,
    culet,
    polish,
    symmetry,
    fluorescence,
    clarity_characteristics,
    inscription,
    encrypted_report_no,
    simple_encrypted_report_no,
    {{ safe_cast_boolean('is_pdf_available') }}               AS is_pdf_available,
    pdf_url,
    propimg,
    digital_card,
    {{ safe_cast_timestamp('created_at') }}                   AS created_at,
    {{ safe_cast_timestamp('updated_at') }}                   AS updated_at

FROM {{ source('gia_edu', 'report_no_data') }}
WHERE report_no IS NOT NULL
ORDER BY report_no, updated_at DESC NULLS LAST, id DESC
