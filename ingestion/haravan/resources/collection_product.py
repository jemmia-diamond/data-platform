from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

DEFAULT_PAGE_LIMIT = 250


def build_collection_product_resource(
    *,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
):
    """Haravan collects (product <-> collection mapping). Full-load each run (the
    Haravan collects endpoint is fetched in full and merged on id), mirroring fn's
    CollectionProductSyncService (`/collects.json` paginated by page)."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    endpoint_params: dict[str, object] = {"limit": DEFAULT_PAGE_LIMIT}
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
                "name": "collection_product",
                "primary_key": "id",
                "write_disposition": "merge",
                "endpoint": {
                    "path": "collects.json",
                    "params": endpoint_params,
                    "data_selector": "collects",
                    "paginator": {
                        "type": "page_number",
                        "page_param": "page",
                        "base_page": 1,
                        "total_path": None,
                    },
                },
            }
        ],
    }
    resource = rest_api_resources(config)[0]
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    resource.max_table_nesting = 0
    return resource


__all__ = ["build_collection_product_resource"]
