from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Iterator, Optional

import dlt
import requests
from dlt.extract.resource import DltResource

from ingestion.db_utils import get_max_updated_at
from ingestion.pipelines import build_dlt_pipeline

from ._client import AdaptiveRateLimiter, get_with_retry
from .conversations import _apply_hints
from .._env_utils import load_page_access_tokens_from_env

logger = logging.getLogger(__name__)

_CONV_ENDPOINT = "/public_api/v2/pages/{page_id}/conversations"
_MSG_ENDPOINT = "/public_api/v1/pages/{page_id}/conversations/{conversation_id}/messages"
_CONV_PAGE_SIZE = 60
_MSG_PAGE_SIZE = 30
_STATE_KEY = "backfill_min_updated_at"
_DEFAULT_BACKFILL_START = "2026-01-01T00:00:00+00:00"


def _from_iso(value: str) -> datetime:
    """Parse an ISO-8601 string to an aware UTC datetime."""
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def _to_ts(dt: datetime) -> int:
    return int(dt.timestamp())


def _fetch_messages(
    base_url: str,
    page_id: str,
    conv_id: str,
    pat: str,
    sync_ts: str,
    rate_limiter: AdaptiveRateLimiter,
) -> Iterator[dict]:
    """Yield all messages for one conversation, with graceful network-error recovery.

    Args:
        base_url: Pancake API base URL.
        page_id: Facebook page ID.
        conv_id: Conversation ID.
        pat: Page access token.
        sync_ts: ISO timestamp to stamp _db_updated_at on each record.
        rate_limiter: Shared adaptive rate limiter.

    Yields:
        Message records enriched with conversation_id, page_id, _db_updated_at.
    """
    url = (
        f"{base_url}/"
        + _MSG_ENDPOINT.lstrip("/")
        .replace("{page_id}", page_id)
        .replace("{conversation_id}", conv_id)
    )
    current_count = 0
    total = 0
    try:
        while True:
            rate_limiter.wait()
            msg_data = get_with_retry(
                url=url,
                params={"page_access_token": pat, "current_count": current_count},
                rate_limiter=rate_limiter,
            ).json()

            if not isinstance(msg_data, dict) or msg_data.get("success") is False:
                logger.warning("Failed to fetch messages conv=%s page=%s.", conv_id, page_id)
                break

            batch = msg_data.get("messages") or []
            if not batch:
                break

            total += len(batch)
            for msg in batch:
                yield {**msg, "conversation_id": conv_id, "page_id": page_id, "_db_updated_at": sync_ts}

            if len(batch) < _MSG_PAGE_SIZE:
                break
            current_count += len(batch)

    except (requests.ConnectionError, requests.Timeout, OSError) as exc:
        logger.warning("Network error fetching messages conv=%s: %s. Saving %d messages.", conv_id, exc, total)


def build_backfill_resources(
    base_url: str,
    page_access_tokens: dict,
    target_start: str = _DEFAULT_BACKFILL_START,
    overlap_hours: int = 7,
    initial_until: Optional[str] = None,
) -> tuple[DltResource, DltResource]:
    """Build backfill resources that crawl conversations+messages from now back to target_start.

    Crash-safe: on any network error the generator returns gracefully so dlt flushes
    whatever was already yielded to the destination.  The minimum updated_at seen in
    this run is persisted in dlt resource state; the next run resumes from
    min_updated_at + overlap_hours to guarantee no gaps.

    Args:
        base_url: Pancake API base URL.
        page_access_tokens: Mapping of page_id → page_access_token.
        target_start: ISO-8601 date to stop backfilling at (inclusive lower bound).
        overlap_hours: Hours of overlap added to the checkpoint on resume to avoid gaps.

    Returns:
        Tuple of (conversations DltResource, messages DltResource).
    """

    @dlt.resource(name="conversations", primary_key="id", write_disposition="merge")
    def backfill_conversations() -> Iterator[dict]:
        """Yield conversations newest-first from checkpoint down to target_start."""
        state = dlt.current.resource_state()
        checkpoint_iso: Optional[str] = state.get(_STATE_KEY)

        if checkpoint_iso:
            until_dt = _from_iso(checkpoint_iso) + timedelta(hours=overlap_hours)
            logger.info("Resuming backfill: checkpoint=%s → until=%s", checkpoint_iso, until_dt.isoformat())
        elif initial_until:
            until_dt = _from_iso(initial_until)
            logger.info("Starting backfill from DB max: until=%s", until_dt.isoformat())
        else:
            until_dt = datetime.now(timezone.utc)
            logger.info("Starting fresh backfill: until=%s", until_dt.isoformat())

        target_dt = _from_iso(target_start)
        if until_dt <= target_dt:
            logger.info("Backfill already complete.")
            return

        since_ts = _to_ts(target_dt)
        until_ts = _to_ts(until_dt)
        sync_ts = datetime.now(timezone.utc).isoformat()
        rate_limiter = AdaptiveRateLimiter()
        run_min_updated_at: Optional[datetime] = None

        for page_id, pat in page_access_tokens.items():
            page_id = str(page_id)
            if not pat:
                logger.warning("Empty PAT for page %s - skipping.", page_id)
                continue

            url = f"{base_url}/{_CONV_ENDPOINT.lstrip('/').replace('{page_id}', page_id)}"
            params: dict[str, Any] = {
                "page_access_token": pat,
                "since": since_ts,
                "until": until_ts,
                "order_by": "updated_at",
            }
            cursor: Optional[str] = None
            total = 0

            try:
                while True:
                    p = {**params}
                    if cursor:
                        p["last_conversation_id"] = cursor

                    rate_limiter.wait()
                    data = get_with_retry(url=url, params=p, rate_limiter=rate_limiter).json()

                    if isinstance(data, dict) and data.get("success") is False:
                        logger.warning(
                            "API error page %s: error_code=%s msg='%s' - stopping segment.",
                            page_id, data.get("error_code"), data.get("message", ""),
                        )
                        break

                    batch = data.get("conversations") or []
                    if not batch:
                        break

                    total += len(batch)
                    for conv in batch:
                        raw_ts = conv.get("updated_at")
                        if raw_ts:
                            try:
                                conv_dt = _from_iso(raw_ts)
                                if run_min_updated_at is None or conv_dt < run_min_updated_at:
                                    run_min_updated_at = conv_dt
                            except (ValueError, TypeError):
                                pass
                        yield {**conv, "page_id": page_id, "_db_updated_at": sync_ts}

                    new_cursor = str(batch[-1].get("id", ""))
                    if len(batch) < _CONV_PAGE_SIZE or not new_cursor or new_cursor == cursor:
                        logger.info("Backfill done page_id=%s total=%d", page_id, total)
                        break
                    cursor = new_cursor

            except (requests.ConnectionError, requests.Timeout, OSError) as exc:
                logger.warning(
                    "Network error page %s after %d conversations: %s - saving progress.",
                    page_id, total, exc,
                )

        if run_min_updated_at:
            state[_STATE_KEY] = run_min_updated_at.isoformat()
            logger.info(
                "Checkpoint saved - next run until=%s",
                (run_min_updated_at + timedelta(hours=overlap_hours)).isoformat(),
            )

    @dlt.transformer(
        name="messages",
        primary_key=["id", "conversation_id", "page_id"],
        write_disposition="merge",
        data_from=backfill_conversations,
    )
    def backfill_messages(conv: dict) -> Iterator[dict]:
        """For each backfilled conversation, fetch all its messages."""
        page_id = str(conv.get("page_id", ""))
        conv_id = str(conv.get("id", ""))
        if not page_id or not conv_id:
            return

        pat = page_access_tokens.get(page_id)
        if not pat:
            logger.warning("No PAT for page %s - skipping messages.", page_id)
            return

        rate_limiter = AdaptiveRateLimiter()
        yield from _fetch_messages(base_url, page_id, conv_id, pat, conv.get("_db_updated_at", ""), rate_limiter)

    return _apply_hints(backfill_conversations), _apply_hints(backfill_messages)


_PIPELINE_NAME = "pancake_backfill"
_DATASET_NAME = "raw_pancake"


@dlt.source(name="pancake")
def backfill_source(
    base_url: str = dlt.config.value,
    page_access_tokens: Optional[dict] = None,
    target_start: str = _DEFAULT_BACKFILL_START,
    overlap_hours: int = 7,
    initial_until: Optional[str] = None,
):
    """dlt source for the one-time historical backfill.

    Args:
        base_url: Pancake API base URL (from dlt config).
        page_access_tokens: Mapping page_id → PAT; loaded from env if omitted.
        target_start: Earliest updated_at to backfill to (ISO-8601).
        overlap_hours: Hours of overlap on resume to close time-window gaps.
        initial_until: Upper bound for the very first run (e.g. DB max updated_at).
            Ignored when a checkpoint already exists in dlt state.

    Returns:
        Tuple of (backfill_conversations, backfill_messages) dlt resources.
    """
    if page_access_tokens is None:
        page_access_tokens = load_page_access_tokens_from_env()
    return build_backfill_resources(
        base_url=base_url,
        page_access_tokens=page_access_tokens,
        target_start=target_start,
        overlap_hours=overlap_hours,
        initial_until=initial_until,
    )


def run_backfill(
    target_start: str = _DEFAULT_BACKFILL_START,
    overlap_hours: int = 7,
) -> None:
    """Query DB max updated_at, then run the backfill pipeline to completion.

    Re-run as many times as needed — each run resumes from the last checkpoint.
    Backfill is complete when the log says "Backfill already complete."

    Args:
        target_start: Earliest updated_at to backfill to (ISO-8601).
        overlap_hours: Hours of overlap on resume to close time-window gaps.
    """
    db_max = get_max_updated_at(_DATASET_NAME, "conversations")
    initial_until = db_max.isoformat() if db_max else None
    if initial_until:
        logger.info("DB max updated_at = %s — using as initial_until.", initial_until)
    else:
        logger.info("conversations table empty — backfill will start from now.")

    pipeline = build_dlt_pipeline(
        connector_name=_PIPELINE_NAME,
        dataset_name=_DATASET_NAME,
    )
    pipeline.run(
        backfill_source(
            target_start=target_start,
            overlap_hours=overlap_hours,
            initial_until=initial_until,
        )
    )


__all__ = ["backfill_source", "build_backfill_resources", "run_backfill"]


if __name__ == "__main__":
    import logging as _logging
    from dotenv import load_dotenv

    load_dotenv()
    _logging.basicConfig(
        level=_logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    )
    run_backfill()
