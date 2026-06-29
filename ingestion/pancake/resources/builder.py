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

from ._client import PAGE_SLEEP_SECONDS, get_with_retry
from .conversations import _apply_hints, build_conversations_and_messages

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


def load_table_specs() -> list[TableSpec]:
    with open(_YAML_PATH) as f:
        return [TableSpec(**t) for t in yaml.safe_load(f)["tables"]]


def build_resource(
    spec: TableSpec,
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> DltResource:
    sync_ts = datetime.now(timezone.utc).isoformat()
    skip_ids = {
        s.strip()
        for s in os.environ.get("SOURCES__PANCAKE__SKIP_PAGE_IDS", "").split(",")
        if s.strip()
    }

    def _iter(since_unix: Optional[int] = None, until_unix: Optional[int] = None):
        for page_id, pat in page_access_tokens.items():
            page_id = str(page_id)
            if not pat:
                continue
            if page_id in skip_ids:
                logger.info("Skipping page %s per SKIP_PAGE_IDS.", page_id)
                continue

            url = f"{base_url}/{spec.endpoint.lstrip('/').replace('{page_id}', page_id)}"
            params: dict[str, Any] = {"page_access_token": pat}
            if since_unix is not None:
                params |= {"since": since_unix, "until": until_unix, "order_by": spec.incremental_cursor}

            page_number = 1
            while True:
                p = {**params}
                if spec.paginated:
                    p |= {"page_number": page_number, "page_size": spec.page_size}

                data = get_with_retry(url=url, params=p).json()
                if isinstance(data, dict) and data.get("success") is False:
                    logger.warning(
                        "API error for page %s: error_code=%s msg='%s' - skipping.",
                        page_id, data.get("error_code"), data.get("message", ""),
                    )
                    break

                items = (data.get(spec.response_key) if spec.response_key and isinstance(data, dict) else data) or []
                if not items:
                    break

                for item in items:
                    yield {**item, "page_id": page_id, "_db_updated_at": sync_ts}

                if not spec.paginated or len(items) < spec.page_size:
                    break
                page_number += 1
                time.sleep(PAGE_SLEEP_SECONDS)

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
            yield from _iter(since, until)
        return _apply_hints(_incremental)

    @dlt.resource(name=spec.name, primary_key=spec.primary_key, write_disposition="merge")
    def _full_refresh():
        yield from _iter()
    return _apply_hints(_full_refresh)


def build_all_resources(
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> list[DltResource]:
    resources = [
        build_resource(spec, base_url, page_access_tokens, start_date, end_date)
        for spec in load_table_specs()
    ]
    resources.extend(build_conversations_and_messages(base_url, page_access_tokens, start_date, end_date))
    return resources


__all__ = [
    "TableSpec",
    "build_all_resources",
    "build_resource",
    "load_table_specs",
]
