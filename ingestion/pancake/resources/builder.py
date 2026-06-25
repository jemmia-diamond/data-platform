from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional, Union

import dlt
import yaml
from dlt.extract.resource import DltResource

from ._client import (
    PAGE_SLEEP_SECONDS,
    generate_page_access_token,
    get_activated_pages,
    get_all_pages,
    get_with_retry,
)

logger = logging.getLogger(__name__)

_YAML_PATH = Path(__file__).parent.parent / "tables_to_sync.yaml"


@dataclass(frozen=True)
class TableSpec:
    endpoint: str
    name: str
    primary_key: Union[str, list]
    sync_type: str
    response_key: Optional[str] = None
    paginated: bool = False
    page_size: int = 50
    incremental_cursor: str = "updated_at"
    cursor_field: Optional[str] = None


def load_table_specs() -> list[TableSpec]:
    with open(_YAML_PATH) as f:
        return [TableSpec(**t) for t in yaml.safe_load(f)["tables"]]


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def _iter_per_page(
    spec: TableSpec,
    base_url: str,
    user_access_token: str,
    sync_ts: str,
    since_unix: Optional[int] = None,
    until_unix: Optional[int] = None,
):
    """Iterate across all activated pages, generating per-page access tokens on the fly."""
    skip_ids = {
        s.strip()
        for s in os.environ.get("SOURCES__PANCAKE__SKIP_PAGE_IDS", "").split(",")
        if s.strip()
    }
    pages = get_activated_pages(base_url=base_url, user_access_token=user_access_token)

    for page in reversed(pages):
        page_id = str(page.get("id", ""))
        if page_id in skip_ids:
            logger.info("Skipping page %s (%s) per SKIP_PAGE_IDS.", page_id, page.get("name"))
            continue

        try:
            pat = generate_page_access_token(
                base_url=base_url, page_id=page_id, user_access_token=user_access_token
            )
        except Exception as exc:
            logger.warning("Could not generate PAT for page %s — skipping. %s", page_id, exc)
            continue

        url = f"{base_url}/{spec.endpoint.lstrip('/').replace('{page_id}', page_id)}"
        base_params: dict[str, Any] = {"page_access_token": pat}
        if since_unix is not None:
            base_params |= {"since": since_unix, "until": until_unix, "order_by": "updated_at"}

        cursor: Optional[str] = None
        page_number = 1
        while True:
            params = {**base_params}
            if spec.cursor_field:
                if cursor:
                    params[spec.cursor_field] = cursor
            elif spec.paginated:
                params |= {"page_number": page_number, "page_size": spec.page_size}

            data = get_with_retry(url=url, params=params).json()
            if not data.get("success", True) and data.get("error_code") == 102:
                logger.warning("Invalid PAT for page %s — skipping.", page_id)
                break

            items = data.get(spec.response_key) or []
            if not items:
                break

            for item in items:
                yield {**item, "page_id": page_id, "_db_updated_at": sync_ts}

            if spec.cursor_field:
                new_cursor = str(items[-1].get("id", ""))
                if len(items) < spec.page_size or not new_cursor or new_cursor == cursor:
                    break
                cursor = new_cursor
            elif spec.paginated:
                if len(items) < spec.page_size:
                    break
                page_number += 1
            else:
                break

            time.sleep(PAGE_SLEEP_SECONDS)


def build_resource(
    spec: TableSpec,
    base_url: str,
    user_access_token: str,
    start_date: str,
    end_date: Optional[str] = None,
) -> DltResource:
    sync_ts = datetime.now(timezone.utc).isoformat()

    # Pages: single global call with user_access_token (no {page_id} in endpoint)
    if "{page_id}" not in spec.endpoint:
        @dlt.resource(name=spec.name, primary_key=spec.primary_key, write_disposition="merge")
        def _global():
            for page in get_all_pages(base_url=base_url, user_access_token=user_access_token):
                yield {**page, "_db_updated_at": sync_ts}
        return _apply_hints(_global)

    # Per-page incremental (conversations, page_customers)
    if spec.sync_type == "incremental":
        @dlt.resource(name=spec.name, primary_key=spec.primary_key, write_disposition="merge")
        def _incremental(
            _cursor=dlt.sources.incremental(spec.incremental_cursor, initial_value=start_date),
        ):
            since = int(datetime.fromisoformat(_cursor.last_value.replace("Z", "+00:00")).timestamp())
            until = (
                int(datetime.fromisoformat(end_date.replace("Z", "+00:00")).timestamp())
                if end_date
                else int(datetime.now(timezone.utc).timestamp())
            )
            yield from _iter_per_page(spec, base_url, user_access_token, sync_ts, since, until)
        return _apply_hints(_incremental)

    # Per-page full refresh (page_users, tags)
    @dlt.resource(name=spec.name, primary_key=spec.primary_key, write_disposition="merge")
    def _full_refresh():
        yield from _iter_per_page(spec, base_url, user_access_token, sync_ts)
    return _apply_hints(_full_refresh)


def build_all_resources(
    base_url: str,
    user_access_token: str,
    start_date: str,
    end_date: Optional[str] = None,
) -> list[DltResource]:
    return [
        build_resource(spec, base_url, user_access_token, start_date, end_date)
        for spec in load_table_specs()
    ]


__all__ = ["TableSpec", "build_all_resources", "build_resource", "load_table_specs"]
