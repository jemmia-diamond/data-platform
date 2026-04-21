from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


def build_locations_resource(
    *,
    base_url: str,
    api_token: str,
):
    """Create the Haravan locations resource (Full Load)."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    
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
                "name": "locations",
                "primary_key": "id",
                "write_disposition": "replace",
                "endpoint": {
                    "path": "locations.json",
                    "data_selector": "locations"
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

__all__ = ["build_locations_resource"]
