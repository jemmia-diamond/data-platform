from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

DEFAULT_PAGE_LIMIT = 50
DEFAULT_ORDER_FIELD = "updated_at"


# Haravan's `order=updated_at` returns newest first. Products updated while a run pages
# through the list shift between pages, so a run can skip some, and the cursor then moves
# past them. The lag makes every run re-read the last hour; merge on `id` dedupes.
INCREMENTAL_LAG_SECONDS = 3600

# A variant edit doesn't always bump the product's `updated_at` (e.g. a price set right after
# the variant was created), so no `updated_at_min` feed can see it. The full reload pages by
# id, which doesn't move while products change, and merges every product again.
FULL_RELOAD_ORDER_FIELD = "id asc"


def _products_resource(
    *,
    name: str,
    base_url: str,
    api_token: str,
    endpoint_params: dict,
    incremental: Optional[dict],
):
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    endpoint: dict = {
        "path": "products.json",
        "params": endpoint_params,
        "data_selector": "products",
        "paginator": {
            "type": "page_number",
            "page_param": "page",
            "base_page": 1,
            "total_path": None,
        },
    }
    if incremental:
        endpoint["incremental"] = incremental

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
                "name": name,
                "primary_key": "id",
                "write_disposition": "merge",
                "endpoint": endpoint,
            }
        ],
    }

    resource = rest_api_resources(config)[0]
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(
        table_name="products",
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        },
    )
    resource.max_table_nesting = 0
    return resource


def build_products_resource(
    *,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
):
    """Create the Haravan products resource (incremental on `updated_at`)."""
    endpoint_params = {
        "limit": DEFAULT_PAGE_LIMIT,
        "order": DEFAULT_ORDER_FIELD,
    }
    if end_date:
        endpoint_params["updated_at_max"] = end_date
    return _products_resource(
        name="products",
        base_url=base_url,
        api_token=api_token,
        endpoint_params=endpoint_params,
        incremental={
            "start_param": "updated_at_min",
            "cursor_path": "updated_at",
            "initial_value": start_date,
            "lag": INCREMENTAL_LAG_SECONDS,
        },
    )


def build_products_full_reload_resource(
    *,
    base_url: str,
    api_token: str,
):
    """Re-read every Haravan product into raw_haravan.products (merge on `id`)."""
    return _products_resource(
        name="products_full_reload",
        base_url=base_url,
        api_token=api_token,
        endpoint_params={
            "limit": DEFAULT_PAGE_LIMIT,
            "order": FULL_RELOAD_ORDER_FIELD,
        },
        incremental=None,
    )


__all__ = ["build_products_resource", "build_products_full_reload_resource"]
