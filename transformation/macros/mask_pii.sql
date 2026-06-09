{% macro mask_email(column_expr) %}
CASE
    WHEN {{ column_expr }} IS NULL OR TRIM({{ column_expr }}::text) = '' THEN NULL
    ELSE REGEXP_REPLACE({{ column_expr }}::text, '^([^@]).+@', '\1***@')
END
{% endmacro %}


{% macro mask_phone(column_expr) %}
CASE
    WHEN {{ column_expr }} IS NULL OR TRIM({{ column_expr }}::text) = '' THEN NULL
    WHEN LENGTH(TRIM({{ column_expr }}::text)) >= 6
        THEN SUBSTRING(TRIM({{ column_expr }}::text), 1, 3) || '***' || RIGHT(TRIM({{ column_expr }}::text), 3)
    ELSE '***'
END
{% endmacro %}


{% macro mask_name(column_expr) %}
CASE
    WHEN {{ column_expr }} IS NULL OR TRIM({{ column_expr }}::text) = '' THEN NULL
    WHEN {{ column_expr }}::text ~ ' ' THEN
        SPLIT_PART({{ column_expr }}::text, ' ', 1)
        || ' '
        || LEFT(SPLIT_PART({{ column_expr }}::text, ' ', array_length(string_to_array({{ column_expr }}::text, ' '), 1)), 1)
        || '***'
    ELSE LEFT({{ column_expr }}::text, 1) || '***'
END
{% endmacro %}


{% macro mask_birth_date(column_expr) %}
CASE
    WHEN {{ column_expr }} IS NULL THEN NULL
    ELSE MAKE_DATE(EXTRACT(YEAR FROM {{ column_expr }}::date)::int, 1, 1)
END
{% endmacro %}
