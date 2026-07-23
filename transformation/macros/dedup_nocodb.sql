{#
    Deduplicate NocoDB source rows by business key, keeping the latest record.
    Rows with NULL business key are dropped (only unique-keyed rows survive).

    Usage:
        FROM {{ dedup_nocodb('diamonds', 'barcode') }}
        FROM {{ dedup_nocodb('products', "COALESCE(haravan_product_id::text, design_code)") }}
#}
{% macro dedup_nocodb(table_name, business_key) %}
    (
        WITH ranked AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY {{ business_key }}
                    ORDER BY database_updated_at DESC NULLS LAST, _db_updated_at DESC
                ) AS _nocodb_dedup_rn
            FROM {{ source('nocodb', table_name) }}
            WHERE NULLIF({{ business_key }}::text, '') IS NOT NULL
        )
        SELECT * FROM ranked WHERE _nocodb_dedup_rn = 1
    )
{% endmacro %}
