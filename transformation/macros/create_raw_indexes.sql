{% macro create_raw_indexes() %}

{% set indexes = [
    ("raw_frappe", "deleted_documents", "deleted_doctype, deleted_name"),
    ("raw_frappe", "sales_orders", "haravan_order_id"),
    ("raw_frappe", "sales_orders", "split_order_group"),
    ("raw_haravan", "orders", "ref_order_id"),
    ("raw_frappe", "leads", "modified"),
    ("raw_frappe", "leads", "name"),
    ("raw_frappe", "contacts", "modified"),
    ("raw_frappe", "contacts", "name"),
] %}

{% for schema, table, columns in indexes %}
    {% set index_name = "idx_" ~ table ~ "_" ~ columns | replace(", ", "_") | replace(",", "_") %}
    {% set sql %}
        CREATE INDEX IF NOT EXISTS {{ index_name }}
        ON {{ schema }}.{{ table }} ({{ columns }});
    {% endset %}

    {% do run_query(sql) %}
    {% do log("Created index " ~ index_name ~ " on " ~ schema ~ "." ~ table, info=true) %}

{% endfor %}

{% endmacro %}
