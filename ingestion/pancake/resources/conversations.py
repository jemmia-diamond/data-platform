from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from typing import Any, Optional

import dlt
from dlt.extract.resource import DltResource

from ingestion.db_utils import get_max_updated_at

from ._client import PAGE_SLEEP_SECONDS, get_with_retry

logger = logging.getLogger(__name__)

_CONV_ENDPOINT = "/public_api/v2/pages/{page_id}/conversations"
_MSG_ENDPOINT = "/public_api/v1/pages/{page_id}/conversations/{conversation_id}/messages"
_CONV_PAGE_SIZE = 60
_MSG_PAGE_SIZE = 30


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def _to_ts(value: str) -> int:
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def build_conversations_and_messages(
    base_url: str,
    page_access_tokens: dict,
    start_date: str,
    end_date: Optional[str] = None,
) -> tuple[DltResource, DltResource]:
    sync_ts = datetime.now(timezone.utc).isoformat()

    @dlt.resource(name="conversations", primary_key="id", write_disposition="merge")
    def conversations():
        """Yield conversations across pages, filtered by updated_at (since/until)."""
        since_cursor = _to_ts(start_date)
        until = _to_ts(end_date) if end_date else int(datetime.now(timezone.utc).timestamp())

        for page_id, pat in page_access_tokens.items():
            page_id = str(page_id)
            if not pat:
                logger.warning("Empty PAT for page %s - skipping.", page_id)
                continue

            db_max = get_max_updated_at("raw_pancake", "conversations", filters={"page_id": page_id})
            if db_max is not None and int(db_max.timestamp()) > since_cursor:
                logger.info(
                    "Page %s: DB max updated_at %s > since %s - advancing since.",
                    page_id, db_max.isoformat(), start_date,
                )
                since = int(db_max.timestamp())
            else:
                since = since_cursor

            url = f"{base_url}/{_CONV_ENDPOINT.lstrip('/').replace('{page_id}', page_id)}"
            params: dict[str, Any] = {
                "page_access_token": pat,
                "since": since,
                "until": until,
                "order_by": "updated_at",
            }
            cursor: Optional[str] = None

            while True:
                p = {**params}
                if cursor:
                    p["last_conversation_id"] = cursor

                data = get_with_retry(url=url, params=p).json()
                if isinstance(data, dict) and data.get("success") is False:
                    logger.warning(
                        "API error for page %s: error_code=%s msg='%s' - skipping.",
                        page_id, data.get("error_code"), data.get("message", ""),
                    )
                    break

                batch = data.get("conversations") or []
                if not batch:
                    break

                for conv in batch:
                    yield {**conv, "page_id": page_id, "_db_updated_at": sync_ts}

                new_cursor = str(batch[-1].get("id", ""))
                if len(batch) < _CONV_PAGE_SIZE or not new_cursor or new_cursor == cursor:
                    break
                cursor = new_cursor
                time.sleep(PAGE_SLEEP_SECONDS)

    @dlt.transformer(
        name="messages",
        primary_key=["id", "conversation_id", "page_id"],
        write_disposition="merge",
        data_from=conversations,
    )
    def messages(conv: dict):
        """For each conversation, page through all its messages via current_count."""
        page_id = str(conv.get("page_id", ""))
        conv_id = str(conv.get("id", ""))
        if not page_id or not conv_id:
            return

        pat = page_access_tokens.get(page_id)
        if not pat:
            logger.warning("No PAT found for page %s - skipping messages.", page_id)
            return

        msg_url = (
            f"{base_url}/"
            + _MSG_ENDPOINT.lstrip("/")
            .replace("{page_id}", page_id)
            .replace("{conversation_id}", conv_id)
        )

        current_count = 0
        while True:
            params = {"page_access_token": pat, "current_count": current_count}
            msg_data = get_with_retry(url=msg_url, params=params).json()

            if not isinstance(msg_data, dict) or msg_data.get("success") is False:
                logger.warning("Failed to fetch messages for conv %s page %s.", conv_id, page_id)
                break

            batch = msg_data.get("messages") or []
            if not batch:
                break

            for msg in batch:
                yield {**msg, "conversation_id": conv_id, "page_id": page_id, "_db_updated_at": sync_ts}

            if len(batch) < _MSG_PAGE_SIZE:
                break
            current_count += len(batch)
            time.sleep(PAGE_SLEEP_SECONDS)

    return _apply_hints(conversations), _apply_hints(messages)


__all__ = ["build_conversations_and_messages"]
