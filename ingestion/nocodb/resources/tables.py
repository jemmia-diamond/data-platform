from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional

from dlt.extract.resource import DltResource
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


@dataclass(frozen=True)
class TableSpec:
    """Specification for a NocoDB table to ingest."""

    resource_name: str
    table_id: str
    primary_key: str
    incremental_field: Optional[str]
    view_id: Optional[str] = None
    fields: Optional[str] = None


# Single source of truth for NocoDB tables to be ingested.
# The table_id can be updated with the actual UUID or table title from NocoDB.
TABLE_SPECS: tuple[TableSpec, ...] = (
    TableSpec(
        resource_name="designs",
        table_id="ma0vp8g1sv25mua",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,database_updated_at"
    ),
    TableSpec(
        resource_name="variant_serials",
        table_id="mm80xzmei7q85k7",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,design_code,database_updated_at"
    ),
)


def build_table_resource(
    *,
    spec: TableSpec,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
) -> DltResource:
    """Create a DltResource for a specific NocoDB table."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    endpoint_params: dict[str, Any] = {
        "limit": 200,
    }
    if spec.view_id:
        endpoint_params["viewId"] = spec.view_id
    if spec.fields:
        endpoint_params["fields"] = spec.fields
    if spec.incremental_field:
        endpoint_params["sort"] = spec.incremental_field

    incremental_config = None
    if spec.incremental_field:
        def _nodb_convert(val: Any) -> str:
            start_clause = f"({spec.incremental_field},ge,exactDate,{val})"
            if end_date:
                return f"{start_clause}~and({spec.incremental_field},lt,exactDate,{end_date})"
            return start_clause

        incremental_config = {
            "cursor_path": spec.incremental_field,
            "initial_value": start_date,
            "start_param": "where",
            "convert": _nodb_convert,
        }

    config: RESTAPIConfig = {
        "client": {
            "base_url": base_url,
            "headers": {
                "xc-token": api_token,
                "Content-Type": "application/json",
            },
        },
        "resources": [
            {
                "name": spec.resource_name,
                "primary_key": spec.primary_key,
                "write_disposition": "merge",
                "endpoint": {
                    "path": f"tables/{spec.table_id}/records",
                    "params": endpoint_params,
                    "data_selector": "list",
                    "paginator": {
                        "type": "offset",
                        "limit": 200,
                        "total_path": "pageInfo.totalRows",
                    },
                    "incremental": incremental_config,
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


__all__ = ["TableSpec", "TABLE_SPECS", "build_table_resource"]
