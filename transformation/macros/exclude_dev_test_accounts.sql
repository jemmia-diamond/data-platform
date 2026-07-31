{% macro exclude_dev_test_accounts(column_expr) %}
{{ column_expr }} IS NULL
    OR {{ column_expr }} NOT IN (
        'an.nguyen@jemmia.vn', 'binh.le@jemmia.vn',
        'lam.phan@jemmia.vn', 'nam.tran@jemmia.vn', 'tuong.le@jemmia.vn'
    )
{% endmacro %}
