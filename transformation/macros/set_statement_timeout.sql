{% macro set_statement_timeout() %}

{% set timeout_ms = env_var('DBT_STATEMENT_TIMEOUT_MS', '1200000') %}
{% set sql %}
    SET statement_timeout = '{{ timeout_ms }}';
{% endset %}

{{ log("Setting statement_timeout to " ~ timeout_ms ~ "ms (" ~ (timeout_ms | int / 1000) ~ "s)", info=True) }}
{{ run_query(sql) }}

{% endmacro %}
