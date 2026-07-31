from __future__ import annotations

import logging
from datetime import datetime, timezone
from time import monotonic, sleep
from typing import Any, Callable, Optional, Union

import dlt
from dlt.extract.resource import DltResource

from ingestion.common import apply_raw_hints
from ingestion.misa.client import MisaClient

logger = logging.getLogger(__name__)

DEFAULT_PAGE_SIZE = 100
MAX_ITERATIONS = 500
MAX_ELAPSED_SECONDS = 600.0
# Politeness delay between pagination requests to stay under MISA's rate limit
# (mirrors fn's RATE_LIMIT_DELAY_MS=500). Skipped before the first page.
PAGE_DELAY_SECONDS = 0.5

# Type alias for the fetch callable shared by all MISA endpoints.
# Returns (rows, last_sync_time_cursor) — same tuple shape as MisaClient methods.
FetchFn = Callable[[int, int, Optional[str]], tuple[list[dict[str, Any]], Optional[str]]]


def build_dictionary_resource(
    client: MisaClient,
    *,
    name: str,
    primary_key: Union[str, list[str]],
    data_type: Optional[int] = None,
    take: int = DEFAULT_PAGE_SIZE,
    fetch_fn: Optional[FetchFn] = None,
    use_cursor: bool = True,
) -> DltResource:
    """Build a dlt resource that pulls a MISA endpoint with ``skip``/``take`` pagination.

    Args:
        client: MISA API client.
        name: dlt resource (table) name.
        primary_key: Column(s) for merge deduplication.
        data_type: MISA get_dictionary type. Required when ``fetch_fn`` is None.
        take: Page size.
        fetch_fn: Custom fetch callable ``(skip, take, last_sync_time) -> (rows, cursor)``.
            When None, defaults to ``client.get_dictionary(data_type=...)``.
        use_cursor: When True (default), drives incremental sync from
            ``CustomData.LastSyncTime``. Set False for balance snapshots that
            should always do a full load (e.g. ``get_list_inventory_balance``).
    """
    if fetch_fn is None:
        if data_type is None:
            raise ValueError("data_type is required when fetch_fn is not provided")
        dt = data_type
        fetch_fn = lambda skip, tk, lst: client.get_dictionary(
            data_type=dt, skip=skip, take=tk, last_sync_time=lst,
        )

    @dlt.resource(name=name, primary_key=primary_key, write_disposition="merge")
    def rows() -> DltResource:
        state = dlt.current.resource_state()
        cursor: Optional[str] = state.get("last_sync_time") if use_cursor else None
        sync_timestamp = datetime.now(timezone.utc).isoformat()

        skip = 0
        iteration = 0
        loop_start = monotonic()
        run_cursor = cursor

        while True:
            iteration += 1
            if iteration > MAX_ITERATIONS:
                logger.warning(
                    "MISA resource %s: exceeded max iterations (%d). Stopping.",
                    name, MAX_ITERATIONS,
                )
                break
            if monotonic() - loop_start > MAX_ELAPSED_SECONDS:
                logger.warning(
                    "MISA resource %s: exceeded max elapsed time (%.0fs). Stopping.",
                    name, MAX_ELAPSED_SECONDS,
                )
                break

            if skip > 0:
                sleep(PAGE_DELAY_SECONDS)

            page_rows, new_cursor = fetch_fn(skip, take, cursor)
            if new_cursor:
                run_cursor = new_cursor

            if not page_rows:
                break

            for row in page_rows:
                row["_db_updated_at"] = sync_timestamp
                yield row

            if len(page_rows) < take:
                break

            skip += take

        # Persist the cursor for the next run. dlt only commits resource state
        # on a successful load, so an interrupted run re-fetches from the old
        # cursor and merge-dedups the overlap.
        if use_cursor and run_cursor and run_cursor != cursor:
            state["last_sync_time"] = run_cursor

    return apply_raw_hints(rows)


__all__ = ["build_dictionary_resource", "DEFAULT_PAGE_SIZE"]
