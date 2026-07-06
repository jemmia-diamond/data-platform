from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Iterator, Optional

import dlt
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests

_logger = logging.getLogger(__name__)

_CONV_ENDPOINT = "/public_api/v2/pages/{page_id}/conversations"
_CONV_PAGE_SIZE = 60


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def _to_timestamp(value: str) -> int:
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def build_conversations(
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> DltResource:
    """Build the conversations resource.

    Per-page cursors are stored in dlt resource state so each ``page_id`` advances
    its own ``updated_at`` independently. Conversations paginate with the
    ``last_conversation_id`` cursor and use ``dlt.sources.helpers.requests`` for
    automatic retry and rate-limit backoff.

    Page-level error isolation: a failing page (token/permission/transient error)
    is logged and skipped — the remaining pages still run and commit their cursors.
    The failing page's cursor is NOT advanced, so it retries from its last
    position next run (only that one page re-attempts).

    Message fetching is handled separately by the Postgres-backed queue
    (``ingestion.pancake.messages_queue``); ``conversations`` only acts as the
    discovery source (its ``message_count`` drives enqueue).
    """
    sync_ts = datetime.now(timezone.utc).isoformat()

    @dlt.resource(name="conversations", primary_key="id", write_disposition="merge")
    def conversations() -> Iterator[dict]:
        """Yield conversations across all pages, each with its own updated_at cursor."""
        state = dlt.current.resource_state()
        global_since_ts = _to_timestamp(start_date)
        until = _to_timestamp(end_date) if end_date else int(datetime.now(timezone.utc).timestamp())

        for page_id, pat in page_access_tokens.items():
            page_id = str(page_id)
            if not pat:
                continue

            try:
                page_cursor: Optional[str] = state.get(page_id)
                since = max(global_since_ts, _to_timestamp(page_cursor)) if page_cursor else global_since_ts

                url = f"{base_url}/{_CONV_ENDPOINT.lstrip('/').replace('{page_id}', page_id)}"
                params: dict[str, Any] = {
                    "page_access_token": pat,
                    "since": since,
                    "until": until,
                    "order_by": "updated_at",
                }
                cursor: Optional[str] = None
                page_max_updated_at: Optional[str] = None

                while True:
                    p = {**params}
                    if cursor:
                        p["last_conversation_id"] = cursor

                    data = requests.get(url, params=p).json()
                    if isinstance(data, dict) and data.get("success") is False:
                        raise RuntimeError(
                            f"Pancake API error for page {page_id}: "
                            f"error_code={data.get('error_code')} msg={data.get('message', '')!r}"
                        )

                    batch = data.get("conversations") or []
                    if not batch:
                        break

                    for conv in batch:
                        raw_ts = conv.get("updated_at")
                        if raw_ts and (page_max_updated_at is None or raw_ts > page_max_updated_at):
                            page_max_updated_at = raw_ts
                        yield {**conv, "page_id": page_id, "_db_updated_at": sync_ts}

                    new_cursor = str(batch[-1].get("id", ""))
                    if len(batch) < _CONV_PAGE_SIZE or not new_cursor or new_cursor == cursor:
                        break
                    cursor = new_cursor

                if page_max_updated_at:
                    state[page_id] = page_max_updated_at
            except Exception as exc:
                # Page-level failure: skip this page, keep going. Its cursor is NOT
                # advanced so it retries from the last position next run; successful
                # pages commit their cursors normally (generator completes cleanly).
                # GeneratorExit/KeyboardInterrupt (BaseException) are NOT caught here.
                _logger.warning("Conversations page %s failed, skipping: %s", page_id, exc)
                continue

    return _apply_hints(conversations)


__all__ = ["build_conversations"]
