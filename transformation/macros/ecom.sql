{% macro ecom_earring_types() %}
('Bông Tai', 'Bông Tai Nguyên Chiếc')
{% endmacro %}

{% macro ecom_warehouses_5() %}
VALUES
    ('[HCM] Cửa Hàng HCM'),
    ('[HN] Cửa Hàng HN'),
    ('[CT] Cửa Hàng Cần Thơ'),
    ('[HCM] Kế Toán'),
    ('[HCM] Admin')
{% endmacro %}

{% macro ecom_warehouses_3() %}
VALUES
    ('[HCM] Cửa Hàng HCM'),
    ('[HN] Cửa Hàng HN'),
    ('[CT] Cửa Hàng Cần Thơ')
{% endmacro %}

{% macro ecom_excluded_diamond_collections() %}
(25, 26, 27, 29)
{% endmacro %}
