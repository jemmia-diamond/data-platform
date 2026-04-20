from __future__ import annotations

from typing import Optional

from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

DEFAULT_PAGE_LIMIT = 50
DEFAULT_ORDER_FIELD = "updated_at"


def build_orders_resource(
    *,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
):
    """Create the Haravan orders resource."""
    endpoint_params = {
        "limit": DEFAULT_PAGE_LIMIT,
        "order": DEFAULT_ORDER_FIELD,
    }
    if end_date:
        endpoint_params["updated_at_max"] = end_date

    config: RESTAPIConfig = {
        "client": {
            "base_url": base_url,
            "headers": {
                "Authorization": f"Bearer {api_token}",
                "Content-Type": "application/json",
            },
        },
        "resources": [
            {
                "name": "orders",
                "primary_key": "id",
                "write_disposition": "merge",
                "endpoint": {
                    "path": "orders.json",
                    "params": endpoint_params,
                    "data_selector": "orders",
                    "paginator": {
                        "type": "page_number",
                        "page_param": "page",
                        "base_page": 1,
                        "total_path": None,
                    },
                    "incremental": {
                        "start_param": "updated_at_min",
                        "cursor_path": "updated_at",
                        "initial_value": start_date,
                    },
                },
            }
        ],
    }

    return rest_api_resources(config)[0]


__all__ = ["build_orders_resource"]
