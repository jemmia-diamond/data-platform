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
    ("raw_gia_edu", "report_no_data", "report_no"),
    ("raw_nocodb", "products_haravan_collection", "products_id"),
    ("raw_nocodb", "products_haravan_collection", "haravan_collections_id"),
    ("raw_nocodb", "diamonds_haravan_collection", "diamond_id"),
    ("raw_nocodb", "diamonds_haravan_collection", "haravan_collection_id"),
    ("raw_nocodb", "variant_serials", "variant_id"),
    ("raw_nocodb", "variant_serials_diamonds", "variant_serials_id"),
    ("raw_nocodb", "design_design_images", "design_id"),
    ("raw_nocodb", "diamonds", "report_no"),
    ("raw_nocodb", "diamonds", "product_id"),
    ("raw_nocodb", "diamonds", "variant_id"),
    ("raw_haravan", "inventory_locations", "variant_id"),
    ("raw_haravan", "inventory_locations", "product_id"),
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
