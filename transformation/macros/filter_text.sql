{% macro filter_text(expression, fallback='Chưa xác định', fallback_is_sql=false, trim=true) -%}
{%- set text_expression -%}
    {%- if trim -%}
        TRIM(({{ expression }})::text)
    {%- else -%}
        ({{ expression }})::text
    {%- endif -%}
{%- endset -%}

{%- if fallback_is_sql -%}
COALESCE(NULLIF({{ text_expression }}, ''), {{ fallback }})
{%- else -%}
COALESCE(NULLIF({{ text_expression }}, ''), '{{ fallback | replace("'", "''") }}')
{%- endif -%}
{%- endmacro %}
