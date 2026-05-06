{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS deleted_document_id,
    
    -- Target Document
    deleted_doctype,
    deleted_name AS document_id,
    new_name,
    
    -- Document Data Snapshot (JSON)
    data AS document_data_json,
    
    -- Status & Flags
    docstatus::int AS docstatus,
    restored::int::boolean AS is_restored,
    idx::int AS idx,
    
    -- Audit & Internal
    owner,
    modified_by,
    
    -- Dates & Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'deleted_documents') }}
