from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

DEFAULT_PAGE_LIMIT = 50
DEFAULT_ORDER_FIELD = "created_at"


from dlt.sources.helpers.rest_client.paginators import BasePaginator

class HaravanSinceIdPaginator(BasePaginator):
    def __init__(self, data_selector: str):
        super().__init__()
        self.data_selector = data_selector
        self.since_id = None

    def update_state(self, response, data: Optional[list] = None) -> None:
        if not data:
            # Fallback to response.json() if data is not directly provided
            data = response.json().get(self.data_selector, [])
            
        if not data:
            self._has_next_page = False
        else:
            self._has_next_page = True
            self.since_id = data[-1]["id"]

    def update_request(self, request) -> None:
        if request.params is None:
            request.params = {}
        if self.since_id is not None:
            request.params["since_id"] = self.since_id
            request.params.pop("page", None)


def build_events_resource(
    *,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
):
    """Create the Haravan events resource."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    endpoint_params = {
        "limit": DEFAULT_PAGE_LIMIT,
        "order": DEFAULT_ORDER_FIELD,  # created_at ASC default
    }
    if end_date:
        endpoint_params["created_at_max"] = end_date

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
                "name": "events",
                "primary_key": "id",
                "write_disposition": "merge",
                "endpoint": {
                    "path": "events.json",
                    "params": endpoint_params,
                    "data_selector": "events",
                    "paginator": HaravanSinceIdPaginator(data_selector="events"),
                    "incremental": {
                        "start_param": "created_at_min",
                        "cursor_path": "created_at",
                        "initial_value": start_date,
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


__all__ = ["build_events_resource"]
