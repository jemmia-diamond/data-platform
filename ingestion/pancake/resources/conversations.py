from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterator, Optional

import dlt
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests

_CONV_ENDPOINT = "/public_api/v2/pages/{page_id}/conversations"
_MSG_ENDPOINT = "/public_api/v1/pages/{page_id}/conversations/{conversation_id}/messages"
_CONV_PAGE_SIZE = 60
_MSG_PAGE_SIZE = 30


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def _to_timestamp(value: str) -> int:
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def build_conversations_and_messages(
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> tuple[DltResource, DltResource]:
    """Build the conversations resource and the messages transformer bound to it.

    Per-page cursors are stored in dlt resource state so each page_id advances
    its own updated_at independently.

    Conversations paginate with the ``last_conversation_id`` cursor (the id of the
    last item in the page); messages paginate with a cumulative ``current_count``
    offset. Both use ``dlt.sources.helpers.requests`` for automatic retry and
    rate-limit backoff.
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

    @dlt.transformer(
        name="messages",
        primary_key=["id", "conversation_id", "page_id"],
        write_disposition="merge",
        data_from=conversations,
    )
    def messages(conv: dict) -> Iterator[dict]:
        """For each conversation, page through all its messages via current_count."""
        page_id = str(conv.get("page_id", ""))
        conv_id = str(conv.get("id", ""))
        if not page_id or not conv_id:
            return

        pat = page_access_tokens.get(page_id)
        if not pat:
            return

        msg_url = (
            f"{base_url}/"
            + _MSG_ENDPOINT.lstrip("/")
            .replace("{page_id}", page_id)
            .replace("{conversation_id}", conv_id)
        )

        current_count = 0
        while True:
            msg_data = requests.get(
                msg_url,
                params={"page_access_token": pat, "current_count": current_count},
            ).json()

            if not isinstance(msg_data, dict) or msg_data.get("success") is False:
                raise RuntimeError(
                    f"Failed to fetch messages for conv {conv_id} page {page_id}"
                )

            batch = msg_data.get("messages") or []
            if not batch:
                break

            for msg in batch:
                yield {**msg, "conversation_id": conv_id, "page_id": page_id, "_db_updated_at": sync_ts}

            if len(batch) < _MSG_PAGE_SIZE:
                break
            current_count += len(batch)

    return _apply_hints(conversations), _apply_hints(messages)


__all__ = ["build_conversations_and_messages"]
