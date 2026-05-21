{#
    Safely cast a text column to NUMERIC.
    Returns NULL when the value is not a valid number.
    
    Usage:
        {{ safe_cast_numeric('price') }}
        {{ safe_cast_numeric('weight', '0') }}
#}
{% macro safe_cast_numeric(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        WHEN {{ column_name }}::text ~ '^[+-]?[\d]+([.][\d]+)?$' THEN {{ column_name }}::numeric
        ELSE {{ default_fallback }}
    END
{% endmacro %}


{#
    Safely cast a text column to INTEGER.
    Returns NULL when the value is not a valid integer.
    
    Usage:
        {{ safe_cast_int('qty_onhand') }}
#}
{% macro safe_cast_int(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        WHEN {{ column_name }}::text ~ '^[+-]?[\d]+$' THEN {{ column_name }}::int
        ELSE {{ default_fallback }}
    END
{% endmacro %}


{#
    Safely cast a text column to BIGINT.
    Returns NULL when the value is not a valid integer.
    
    Usage:
        {{ safe_cast_bigint('product_id') }}
#}
{% macro safe_cast_bigint(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        WHEN {{ column_name }}::text ~ '^[+-]?[\d]+$' THEN {{ column_name }}::bigint
        ELSE {{ default_fallback }}
    END
{% endmacro %}


{#
    Safely cast a text column to BOOLEAN.
    Handles NocoDB display values like 'true'/'false', 'True'/'False', 'Should Publish' etc.
    
    Usage:
        {{ safe_cast_boolean('published') }}
#}
{% macro safe_cast_boolean(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM(LOWER({{ column_name }}::text)) IN ('true', 'yes', '1', 'on') THEN TRUE
        WHEN TRIM(LOWER({{ column_name }}::text)) IN ('false', 'no', '0', 'off', '') THEN FALSE
        ELSE {{ default_fallback }}
    END
{% endmacro %}


{#
    Safely cast a text column to TIMESTAMP.
    Returns NULL when the value is not a valid timestamp.
    
    Usage:
        {{ safe_cast_timestamp('created_at') }}
#}
{% macro safe_cast_timestamp(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        WHEN {{ column_name }}::text ~ '^\d{4}-\d{2}-\d{2}' THEN {{ column_name }}::timestamp
        ELSE {{ default_fallback }}
    END
{% endmacro %}


{#
    Safely cast a text column to DATE.
    Returns NULL when the value is not a valid date.
    
    Usage:
        {{ safe_cast_date('arrival_date') }}
#}
{% macro safe_cast_date(column_name, default_fallback='NULL') %}
    CASE
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        WHEN {{ column_name }}::text ~ '^\d{4}-\d{2}-\d{2}' THEN {{ column_name }}::date
        ELSE {{ default_fallback }}
    END
{% endmacro %}
