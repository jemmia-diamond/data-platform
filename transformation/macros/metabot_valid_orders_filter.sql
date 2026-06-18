{% macro metabot_valid_orders_filter() %}
    order_number LIKE 'ORDER%'
    AND sales_channel NOT IN ('sendo', 'harafunnel')
    AND sales_channel NOT LIKE '%bhsc%'
    AND haravan_cancelled_status = 'uncancelled'
    AND haravan_confirmed_status = 'confirmed'
    AND (haravan_tags IS NULL OR haravan_tags NOT LIKE '%Lên bù cho đơn SO%')
    AND haravan_total_price > '120000'
{% endmacro %}
