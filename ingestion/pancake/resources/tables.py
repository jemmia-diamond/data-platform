from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional, Union

import dlt
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests

DEFAULT_PAGE_SIZE = 100
PAGE_SLEEP_SECONDS = 1.0


@dataclass(frozen=True)
class TableSpec:
    """Specification for a Pancake REST resource.

    Mirrors the NocoDB ``TableSpec`` pattern: an explicit, type-safe declaration
    of one resource instead of a generic YAML loader.
    """

    resource_name: str
    endpoint: str
    response_key: str
    primary_key: Union[str, list[str]]
    incremental_cursor: Optional[str] = None
    paginated: bool = False
    page_size: int = DEFAULT_PAGE_SIZE


TABLE_SPECS: tuple[TableSpec, ...] = (
    TableSpec(
        resource_name="page_customers",
        endpoint="/public_api/v1/pages/{page_id}/page_customers",
        response_key="customers",
        primary_key="id",
        incremental_cursor="updated_at",
        paginated=True,
        page_size=100,
    ),
    TableSpec(
        resource_name="page_users",
        endpoint="/public_api/v1/pages/{page_id}/users",
        response_key="users",
        primary_key="id",
    ),
    TableSpec(
        resource_name="tags",
        endpoint="/public_api/v1/pages/{page_id}/tags",
        response_key="tags",
        primary_key=["id", "page_id"],
    ),
)


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def _to_timestamp(value: str) -> int:
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def _fetch(
    spec: TableSpec,
    base_url: str,
    page_access_tokens: dict,
    sync_ts: str,
    since: Optional[int] = None,
    until: Optional[int] = None,
):
    """Iterate one resource across all pages, paginating per Facebook page.

    Uses ``dlt.sources.helpers.requests`` which provides automatic retry and
    rate-limit (429) backoff, so no custom retry client is required.
    """
    for raw_page_id, pat in page_access_tokens.items():
        page_id = str(raw_page_id)
        if not pat:
            continue

        url = f"{base_url}/{spec.endpoint.lstrip('/').replace('{page_id}', page_id)}"
        base_params: dict[str, Any] = {"page_access_token": pat}
        if since is not None:
            base_params["since"] = since
            base_params["until"] = until
            base_params["order_by"] = spec.incremental_cursor

        page_number = 1
        while True:
            params = {**base_params}
            if spec.paginated:
                params["page_number"] = page_number
                params["page_size"] = spec.page_size

            data = requests.get(url, params=params).json()
            if isinstance(data, dict) and data.get("success") is False:
                break

            items = (data.get(spec.response_key) if isinstance(data, dict) else data) or []
            if not items:
                break

            for item in items:
                yield {**item, "page_id": page_id, "_db_updated_at": sync_ts}

            if not spec.paginated or len(items) < spec.page_size:
                break
            page_number += 1
            time.sleep(PAGE_SLEEP_SECONDS)


def build_table_resource(
    spec: TableSpec,
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> DltResource:
    """Create a DltResource for a single Pancake table spec."""
    sync_ts = datetime.now(timezone.utc).isoformat()

    if spec.incremental_cursor:
        @dlt.resource(
            name=spec.resource_name,
            primary_key=spec.primary_key,
            write_disposition="merge",
        )
        def _incremental(
            _cursor=dlt.sources.incremental(spec.incremental_cursor, initial_value=start_date),
        ):
            since = _to_timestamp(_cursor.last_value)
            until = _to_timestamp(end_date) if end_date else int(datetime.now(timezone.utc).timestamp())
            yield from _fetch(spec, base_url, page_access_tokens, sync_ts, since, until)
        return _apply_hints(_incremental)

    @dlt.resource(
        name=spec.resource_name,
        primary_key=spec.primary_key,
        write_disposition="merge",
    )
    def _full_refresh():
        yield from _fetch(spec, base_url, page_access_tokens, sync_ts)
    return _apply_hints(_full_refresh)


__all__ = ["TableSpec", "TABLE_SPECS", "build_table_resource"]
