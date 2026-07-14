"""Postgres-backed queue + in-process worker pool for Pancake ``messages``.

``conversations`` stays a normal dlt incremental resource and acts as discovery.
This module drains a ``pancake_sync.message_jobs`` queue whose jobs are derived
from ``raw_pancake.conversations`` (``message_count > 0``). Extract (Pancake
messages API) is decoupled from load (dlt): workers are stateless HTTP fetchers,
and only the main thread touches the DB and the dlt pipeline.

Thread-safety model
-------------------
Workers push ``Chunk`` (rows + offset) and one ``Terminal`` per job onto a
thread-safe ``queue.Queue``. The main thread — sole owner of the dlt pipeline
and the Postgres connection — claims jobs, batch-loads chunks via dlt,
checkpoints ``current_count`` per chunk, and writes the terminal status. This
yields per-page-group resume granularity with zero cross-thread resource
sharing.
"""

from __future__ import annotations

import logging
import queue
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Iterator, NamedTuple, TypedDict

import dlt
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests

from ingestion.pipelines import build_dlt_pipeline

_log = logging.getLogger(__name__)

# --------------------------------------------------------------------------- #
# Names
# --------------------------------------------------------------------------- #
PANCAKE_DATASET_NAME = "raw_pancake"
QUEUE_SCHEMA = "pancake_sync"
QUEUE_TABLE = "message_jobs"
QUEUE_QUALIFIED = f"{QUEUE_SCHEMA}.{QUEUE_TABLE}"
PAGE_HEALTH_TABLE = f"{QUEUE_SCHEMA}.page_health"

# --------------------------------------------------------------------------- #
# Worker / drain tuning
# --------------------------------------------------------------------------- #
MAX_WORKERS = 16             # concurrent conversations per drain tick (was 8)
PER_PAGE_CONCURRENCY = 8     # max in-flight requests per page_access_token
MSG_PAGE_SIZE = 30           # Pancake messages page size
LOAD_BATCH = 500             # flush buffer to dlt at this many rows
MAX_ATTEMPTS = 5             # retryable attempts before a job is promoted to dead
DRAIN_BUDGET_SECONDS = 1500  # wall-clock budget per drain tick (≤ 30 min cron ⇒ no overlap)
STUCK_THRESHOLD_MIN = 10     # "running" jobs older than this are swept to pending
CLAIM_BATCH_SIZE = MAX_WORKERS
MAX_JOB_SECONDS = 180        # per-job wall-clock guard
MAX_JOB_ITERATIONS = 2000    # per-job pagination guard
PAGE_COOLDOWN_MAX_MIN = 60   # circuit-breaker backoff cap (minutes)
# Edit/removal refresh: how many "done" jobs whose conversation changed since
# last pull are re-queued per daily tick. Bounds API cost of catching edits.
EDIT_REFRESH_LIMIT = 2000
# Abort the drain after this many CONSECUTIVE load failures — likely a DB
# outage, not a single bad job. Below the threshold, the failing job is
# isolated (marked pending +1 attempt) and the drain continues with the rest.
MAX_CONSECUTIVE_FLUSH_FAILURES = 3

# --------------------------------------------------------------------------- #
# New-message strategy: SAFE full re-pull (branch "B3")
# --------------------------------------------------------------------------- #
# On message_count growth a done job resets current_count=0, so the worker
# re-fetches the WHOLE conversation (merge dedup on PK updates existing rows).
# Correct regardless of the messages-API ordering — no probe needed.
#
# Optimize later ONLY after running the API probe (plan Task #0): if the
# messages endpoint supports `since` ⇒ switch to timestamp-watermark (cheap);
# elif it is append-only ⇒ resume-from-offset (cheap). Both are future changes
# localized to `_ENQUEUE_SQL` (current_count handling) + the worker fetch loop.

# --------------------------------------------------------------------------- #
# Pancake messages API
# --------------------------------------------------------------------------- #
MSG_ENDPOINT = "/public_api/v1/pages/{page_id}/conversations/{conversation_id}/messages"


# --------------------------------------------------------------------------- #
# Worker → main thread protocol
# --------------------------------------------------------------------------- #
class JobKey(NamedTuple):
    """Composite key of a message job: (page_id, conversation_id)."""

    page_id: str
    conversation_id: str


class ClaimedJob(TypedDict):
    """A claimed job row — shape of ``_CLAIM_SQL``'s RETURNING clause."""

    page_id: str
    conversation_id: str
    message_count: int
    current_count: int


class Chunk(NamedTuple):
    """A fetched page of messages and the resulting offset."""

    job_key: JobKey
    offset_after: int
    rows: list[dict]


class Terminal(NamedTuple):
    """A job finished: ``done`` (fully drained), ``dead`` (unrecoverable), or
    ``pending`` (retryable / reset without burning an attempt)."""

    job_key: JobKey
    status: str               # "done" | "dead" | "pending"
    retryable: bool = False   # increment attempts when True
    page_fatal: bool = False  # open the page circuit breaker
    error: str | None = None
    offset_after: int | None = None


@dataclass
class _Buffer:
    """Rows accumulated for one job between dlt flushes."""

    rows: list[dict] = field(default_factory=list)
    offset: int = 0


# --------------------------------------------------------------------------- #
# Page-fatal error detection
#
# Pancake error codes are numeric (105 = access_token renewed, 106 = invalid
# token, 107 = permission denied). The catalogue is undocumented, so we match
# message text heuristically too. A page-fatal error opens the circuit breaker
# so subsequent claims skip the page until ``next_retry_at``.
# --------------------------------------------------------------------------- #
_FATAL_ERROR_CODES = frozenset(
    {
        "105",  # access_token renewed please use new access_token
        "106",  # invalid access token
        "107",  # permission denied / not authorized
        "invalid_access_token",
        "invalid_token",
        "access_token_expired",
        "invalid_page_access_token",
        "permission_denied",
        "not_authorized",
    }
)


def _is_page_fatal_error(err_code: Any, err_msg: str) -> bool:
    """True when the error indicates the whole page token is unusable."""
    if err_code is not None and str(err_code) in _FATAL_ERROR_CODES:
        return True
    msg = (err_msg or "").lower()
    return "access_token" in msg or ("token" in msg and "invalid" in msg)


# --------------------------------------------------------------------------- #
# SQL — schema bootstrap
# --------------------------------------------------------------------------- #
_CREATE_SCHEMA_SQL = f"CREATE SCHEMA IF NOT EXISTS {QUEUE_SCHEMA};"

_CREATE_TABLE_SQL = f"""
CREATE TABLE IF NOT EXISTS {QUEUE_QUALIFIED} (
    page_id         varchar     NOT NULL,
    conversation_id varchar     NOT NULL,
    message_count   bigint      NOT NULL DEFAULT 0,
    status          varchar     NOT NULL DEFAULT 'pending',
    current_count   integer     NOT NULL DEFAULT 0,
    attempts        integer     NOT NULL DEFAULT 0,
    last_error      text,
    enqueued_at     timestamptz NOT NULL DEFAULT now(),
    started_at      timestamptz,
    finished_at     timestamptz,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    conv_updated_at timestamptz,                 -- conversation updated_at at last full pull (edit detection)
    PRIMARY KEY (page_id, conversation_id)
);
"""

# Additive migration for existing tables (idempotent — runs on every bootstrap).
_ADD_CONV_UPDATED_AT_SQL = (
    f"ALTER TABLE {QUEUE_QUALIFIED} ADD COLUMN IF NOT EXISTS conv_updated_at timestamptz;"
)

_CREATE_PAGE_HEALTH_SQL = f"""
CREATE TABLE IF NOT EXISTS {PAGE_HEALTH_TABLE} (
    page_id           varchar     PRIMARY KEY,
    healthy           boolean     NOT NULL DEFAULT true,
    consecutive_fails integer     NOT NULL DEFAULT 0,
    last_error        text,
    next_retry_at     timestamptz,
    updated_at        timestamptz NOT NULL DEFAULT now()
);
"""

_CREATE_INDEXES_SQL = (
    f"CREATE INDEX IF NOT EXISTS ix_message_jobs_claim "
    f"ON {QUEUE_QUALIFIED} (page_id, updated_at) WHERE status = 'pending';",
    f"CREATE INDEX IF NOT EXISTS ix_message_jobs_stuck "
    f"ON {QUEUE_QUALIFIED} (started_at) WHERE status = 'running';",
    f"CREATE INDEX IF NOT EXISTS ix_message_jobs_refresh "
    f"ON {QUEUE_QUALIFIED} (conv_updated_at) WHERE status = 'done';",
)

# Merge-key index on the target table. dlt merge does DELETE+INSERT by
# (id, conversation_id, page_id); without this index every pipeline.run() flush
# seq-scans the growing raw_pancake.messages table — catastrophic at 1M+ rows.
_CREATE_MESSAGES_MERGE_INDEX_SQL = (
    f"CREATE INDEX IF NOT EXISTS ix_messages_merge_key "
    f"ON {PANCAKE_DATASET_NAME}.messages (id, conversation_id, page_id);"
)


# --------------------------------------------------------------------------- #
# SQL — queue operations
# --------------------------------------------------------------------------- #
# Upsert message jobs from raw_pancake.conversations. New conversations become
# pending (current_count=0). Existing "done" jobs whose message_count grew drop
# back to pending AND reset current_count=0 (SAFE full re-pull — see "New-message
# strategy" above); merge dedup on PK updates existing rows so re-pull is safe.
_ENQUEUE_SQL = f"""
WITH affected AS (
    INSERT INTO {QUEUE_QUALIFIED} (page_id, conversation_id, message_count)
    SELECT page_id, id, message_count
    FROM {PANCAKE_DATASET_NAME}.conversations
    WHERE message_count > 0
    ON CONFLICT (page_id, conversation_id) DO UPDATE
    SET message_count = EXCLUDED.message_count,
        status = CASE
            WHEN {QUEUE_QUALIFIED}.status = 'done'
             AND EXCLUDED.message_count > {QUEUE_QUALIFIED}.message_count
                THEN 'pending'
            ELSE {QUEUE_QUALIFIED}.status
        END,
        current_count = CASE
            WHEN {QUEUE_QUALIFIED}.status = 'done'
             AND EXCLUDED.message_count > {QUEUE_QUALIFIED}.message_count
                THEN 0
            ELSE {QUEUE_QUALIFIED}.current_count
        END,
        updated_at = now()
    WHERE {QUEUE_QUALIFIED}.message_count <> EXCLUDED.message_count
       OR ({QUEUE_QUALIFIED}.status = 'done'
           AND EXCLUDED.message_count > {QUEUE_QUALIFIED}.message_count)
    RETURNING 1
)
SELECT count(*) FROM affected;
"""

# Reclaim jobs whose run died mid-flight (crash / OOM / daemon restart).
_SWEEP_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET status = 'pending', updated_at = now()
WHERE status = 'running'
  AND started_at < now() - (%s || ' minutes')::interval;
"""

# Claim a batch of due, non-cooldown-blocked jobs — ONE job per page (round-robin)
# so the per-page semaphore spreads load across many pages instead of serializing
# within a single page. DISTINCT ON (page_id) picks the earliest-eligible job per
# page; LIMIT caps the batch at the worker-pool size. The outer UPDATE re-checks
# status='pending' to prevent double-claims under concurrent drains (FOR UPDATE
# SKIP LOCKED cannot coexist with DISTINCT ON, so the status guard replaces it).
_CLAIM_SQL = f"""
WITH one_per_page AS (
    SELECT DISTINCT ON (page_id) ctid
    FROM {QUEUE_QUALIFIED}
    WHERE status = 'pending'
      AND updated_at + (POWER(2.0, LEAST(attempts, 8)) * interval '1 second') <= now()
      AND page_id NOT IN (
          SELECT page_id FROM {PAGE_HEALTH_TABLE}
          WHERE next_retry_at IS NOT NULL AND next_retry_at > now()
      )
    ORDER BY page_id, enqueued_at
    LIMIT %s
)
UPDATE {QUEUE_QUALIFIED} AS j
SET status = 'running', started_at = now(), updated_at = now()
FROM one_per_page
WHERE j.ctid = one_per_page.ctid
  AND j.status = 'pending'
RETURNING j.page_id, j.conversation_id, j.message_count, j.current_count;
"""

_CHECKPOINT_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET current_count = %s, updated_at = now()
WHERE page_id = %s AND conversation_id = %s AND status = 'running';
"""

_FINALIZE_DONE_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET status = 'done', current_count = COALESCE(%s, current_count),
    conv_updated_at = COALESCE(
        (SELECT updated_at FROM {PANCAKE_DATASET_NAME}.conversations
         WHERE page_id = {QUEUE_QUALIFIED}.page_id
           AND id = {QUEUE_QUALIFIED}.conversation_id),
        conv_updated_at
    ),
    finished_at = now(), updated_at = now()
WHERE page_id = %s AND conversation_id = %s AND status = 'running'
RETURNING status;
"""

_FINALIZE_DEAD_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET status = 'dead', current_count = COALESCE(%s, current_count),
    last_error = %s, finished_at = now(), updated_at = now()
WHERE page_id = %s AND conversation_id = %s AND status = 'running'
RETURNING status;
"""

# Retryable failure: increment attempts; promote to dead at MAX_ATTEMPTS.
_FINALIZE_RETRY_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET status = CASE WHEN attempts + 1 >= %s THEN 'dead' ELSE 'pending' END,
    attempts = attempts + 1,
    last_error = %s,
    started_at = NULL,
    current_count = COALESCE(%s, current_count),
    finished_at = CASE WHEN attempts + 1 >= %s THEN now() ELSE finished_at END,
    updated_at = now()
WHERE page_id = %s AND conversation_id = %s AND status = 'running'
RETURNING status;
"""

# job_timeout / iteration limit: reset to pending WITHOUT burning an attempt so
# the next tick resumes cleanly from the persisted current_count.
_FINALIZE_RESET_SQL = f"""
UPDATE {QUEUE_QUALIFIED}
SET status = 'pending', started_at = NULL,
    current_count = COALESCE(%s, current_count), updated_at = now()
WHERE page_id = %s AND conversation_id = %s AND status = 'running'
RETURNING status;
"""

_COUNT_STATUS_SQL = f"SELECT count(*) FROM {QUEUE_QUALIFIED} WHERE status = %s;"


# --------------------------------------------------------------------------- #
# SQL — per-page circuit breaker (page_health)
# --------------------------------------------------------------------------- #
# Enroll known pages as healthy (idempotent) so the INSERT branch below has a
# row to update on the first failure.
_ENROLL_PAGES_SQL = f"""
INSERT INTO {PAGE_HEALTH_TABLE} (page_id, healthy, next_retry_at)
SELECT DISTINCT page_id, true, NULL::timestamptz
FROM {PANCAKE_DATASET_NAME}.conversations
WHERE message_count > 0
ON CONFLICT (page_id) DO NOTHING;
"""

# Open the circuit: exponential backoff capped at PAGE_COOLDOWN_MAX_MIN minutes.
_MARK_PAGE_UNHEALTHY_SQL = f"""
INSERT INTO {PAGE_HEALTH_TABLE} AS ph
    (page_id, healthy, consecutive_fails, last_error, next_retry_at, updated_at)
VALUES (%s, false, 1, %s,
        now() + (LEAST(POWER(2, 1), %s) * interval '1 minute'), now())
ON CONFLICT (page_id) DO UPDATE
SET healthy = false,
    consecutive_fails = ph.consecutive_fails + 1,
    last_error = EXCLUDED.last_error,
    next_retry_at = now() + (LEAST(POWER(2, ph.consecutive_fails + 1), %s) * interval '1 minute'),
    updated_at = now();
"""

# Close the circuit: a successful job proves the token works again. Only writes
# when the page was previously unhealthy (no churn for healthy pages).
_MARK_PAGE_HEALTHY_SQL = f"""
INSERT INTO {PAGE_HEALTH_TABLE} AS ph
    (page_id, healthy, consecutive_fails, next_retry_at, updated_at)
VALUES (%s, true, 0, NULL, now())
ON CONFLICT (page_id) DO UPDATE
SET healthy = true,
    consecutive_fails = 0,
    last_error = NULL,
    next_retry_at = NULL,
    updated_at = now()
WHERE ph.healthy = false
   OR ph.consecutive_fails > 0;
"""

_BLOCKED_PAGES_SQL = f"""
SELECT page_id, consecutive_fails, next_retry_at, last_error
FROM {PAGE_HEALTH_TABLE}
WHERE healthy = false
ORDER BY next_retry_at NULLS LAST;
"""

_PAGE_PROGRESS_SQL = f"""
SELECT j.page_id,
       h.healthy,
       count(*) FILTER (WHERE j.status = 'done')    AS done,
       count(*) FILTER (WHERE j.status = 'pending') AS pending,
       coalesce(sum(j.message_count), 0)            AS target,
       coalesce(sum(j.current_count), 0)            AS loaded
FROM {QUEUE_QUALIFIED} j
LEFT JOIN {PAGE_HEALTH_TABLE} h ON h.page_id = j.page_id
GROUP BY j.page_id, h.healthy
ORDER BY j.page_id;
"""

# --------------------------------------------------------------------------- #
# SQL — edit/removal refresh
# --------------------------------------------------------------------------- #
# Re-queue up to `limit` "done" jobs whose conversation changed since the last
# full pull (conversations.updated_at > conv_updated_at) OR whose snapshot was
# never taken (NULL — self-heals rows predating the column). Edits/removals can
# land on any offset, so current_count resets to 0 (full re-pull). Oldest-stale
# first so the stalest conversations are caught up earliest.
_REFRESH_EDITS_SQL = f"""
WITH candidates AS (
    SELECT j.page_id, j.conversation_id
    FROM {QUEUE_QUALIFIED} j
    JOIN {PANCAKE_DATASET_NAME}.conversations c
      ON c.page_id = j.page_id AND c.id = j.conversation_id
    WHERE j.status = 'done'
      AND (c.updated_at > j.conv_updated_at OR j.conv_updated_at IS NULL)
    ORDER BY j.conv_updated_at ASC NULLS FIRST
    LIMIT %s
)
UPDATE {QUEUE_QUALIFIED}
SET status = 'pending', current_count = 0, updated_at = now()
FROM candidates
WHERE {QUEUE_QUALIFIED}.page_id = candidates.page_id
  AND {QUEUE_QUALIFIED}.conversation_id = candidates.conversation_id;
"""


# --------------------------------------------------------------------------- #
# Schema bootstrap
# --------------------------------------------------------------------------- #
def ensure_queue_schema(conn) -> None:
    """Create the pancake_sync schema, queue table, page_health, and indexes.

    Also ensures the merge-key index on raw_pancake.messages exists (guarded
    against the table not being loaded yet on a fresh deployment).
    """
    with conn.cursor() as cur:
        cur.execute(_CREATE_SCHEMA_SQL)
        cur.execute(_CREATE_TABLE_SQL)
        cur.execute(_ADD_CONV_UPDATED_AT_SQL)
        cur.execute(_CREATE_PAGE_HEALTH_SQL)
        for stmt in _CREATE_INDEXES_SQL:
            cur.execute(stmt)
    conn.commit()
    _ensure_messages_merge_index(conn)


def _ensure_messages_merge_index(conn) -> None:
    """Idempotently create the merge-key index on raw_pancake.messages."""
    with conn.cursor() as cur:
        cur.execute(f"SELECT to_regclass('{PANCAKE_DATASET_NAME}.messages')")
        if cur.fetchone()[0] is not None:
            cur.execute(_CREATE_MESSAGES_MERGE_INDEX_SQL)
    conn.commit()


# --------------------------------------------------------------------------- #
# Queue reads / writes (single connection, main thread only)
# --------------------------------------------------------------------------- #
def _sweep_stuck(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(_SWEEP_SQL, (str(STUCK_THRESHOLD_MIN),))
        swept = cur.rowcount
    conn.commit()
    return swept


def _claim_batch(conn, batch_size: int) -> list[ClaimedJob]:
    with conn.cursor() as cur:
        cur.execute(_CLAIM_SQL, (batch_size,))
        rows = cur.fetchall()
    conn.commit()
    return [
        ClaimedJob(
            page_id=str(page_id),
            conversation_id=str(conv_id),
            message_count=int(message_count),
            current_count=int(current_count),
        )
        for page_id, conv_id, message_count, current_count in rows
    ]


def _checkpoint(conn, key: JobKey, offset: int) -> None:
    with conn.cursor() as cur:
        cur.execute(_CHECKPOINT_SQL, (offset, key.page_id, key.conversation_id))
    conn.commit()


def _count_status(conn, status: str) -> int:
    with conn.cursor() as cur:
        cur.execute(_COUNT_STATUS_SQL, (status,))
        return cur.fetchone()[0]


def _finalize_job(conn, term: Terminal, stats: dict[str, Any]) -> None:
    """Apply one terminal: update the job row and page health in one transaction."""
    key = term.job_key
    with conn.cursor() as cur:
        final_status = _write_job_status(cur, key, term)
        _adjust_page_health(cur, key.page_id, term, stats)
    conn.commit()

    if final_status == "done":
        stats["done"] += 1
    elif final_status == "dead":
        stats["dead"] += 1
    else:
        stats["retried"] += 1


def _write_job_status(cur, key: JobKey, term: Terminal) -> str:
    """UPDATE the job row for a terminal; returns the resulting status (RETURNING)."""
    if term.status == "done":
        cur.execute(_FINALIZE_DONE_SQL, (term.offset_after, key.page_id, key.conversation_id))
    elif term.status == "dead":
        cur.execute(
            _FINALIZE_DEAD_SQL,
            (term.offset_after, term.error, key.page_id, key.conversation_id),
        )
    elif term.retryable:
        cur.execute(
            _FINALIZE_RETRY_SQL,
            (MAX_ATTEMPTS, term.error, term.offset_after, MAX_ATTEMPTS, key.page_id, key.conversation_id),
        )
    else:
        cur.execute(_FINALIZE_RESET_SQL, (term.offset_after, key.page_id, key.conversation_id))
    return cur.fetchone()[0]


def _adjust_page_health(cur, page_id: str, term: Terminal, stats: dict[str, Any]) -> None:
    """Page-level circuit breaker: open on a page-fatal, close on a successful job."""
    if term.page_fatal:
        cur.execute(
            _MARK_PAGE_UNHEALTHY_SQL,
            (page_id, term.error, PAGE_COOLDOWN_MAX_MIN, PAGE_COOLDOWN_MAX_MIN),
        )
        stats["pages_blocked"] += 1
    elif term.status == "done":
        cur.execute(_MARK_PAGE_HEALTHY_SQL, (page_id,))


# --------------------------------------------------------------------------- #
# Reporting helpers (ops / debugging)
# --------------------------------------------------------------------------- #
def _blocked_pages(conn) -> list[dict]:
    """Pages currently skipped by the circuit breaker (token error + cooldown)."""
    with conn.cursor() as cur:
        cur.execute(_BLOCKED_PAGES_SQL)
        return [
            {
                "page_id": page_id,
                "consecutive_fails": fails,
                "next_retry_at": retry_at,
                "last_error": last_error,
            }
            for page_id, fails, retry_at, last_error in cur.fetchall()
        ]


def page_progress(conn) -> list[dict]:
    """Per-page cursor snapshot: done / pending / target / loaded / remaining."""
    with conn.cursor() as cur:
        cur.execute(_PAGE_PROGRESS_SQL)
        return [
            {
                "page_id": page_id,
                "healthy": healthy,
                "done": int(done),
                "pending": int(pending),
                "target": int(target),
                "loaded": int(loaded),
                "remaining": int(target) - int(loaded),
            }
            for page_id, healthy, done, pending, target, loaded in cur.fetchall()
        ]


def refresh_edit_jobs(conn, limit: int = EDIT_REFRESH_LIMIT) -> dict[str, int]:
    """Re-queue up to ``limit`` done jobs whose conversation changed since last pull.

    Catches edits/removals the new-message path misses (those bump
    ``conversations.updated_at`` without changing ``message_count``). Jobs reset
    to ``pending`` with ``current_count=0`` (full re-pull — edits can be on any
    offset). Also self-heals done rows whose ``conv_updated_at`` is NULL.
    """
    ensure_queue_schema(conn)
    with conn.cursor() as cur:
        cur.execute(_REFRESH_EDITS_SQL, (limit,))
        refreshed = cur.rowcount
    conn.commit()
    return {"refreshed": refreshed}


# --------------------------------------------------------------------------- #
# dlt plumbing
# --------------------------------------------------------------------------- #
def build_messages_pipeline():
    """Single stable dlt pipeline for batched message loads (state on disk)."""
    return build_dlt_pipeline(
        connector_name="pancake_messages",
        dataset_name=PANCAKE_DATASET_NAME,
    )


def _messages_dlt_resource(rows: list[dict]) -> DltResource:
    """Build a single-use dlt resource matching the raw_pancake.messages shape."""

    @dlt.resource(
        name="messages",
        primary_key=["id", "conversation_id", "page_id"],
        write_disposition="merge",
    )
    def _r() -> Iterator[dict]:
        yield rows

    _r.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    _r.max_table_nesting = 0
    return _r


def _flush_buffer(conn, pipeline, key: JobKey, buf: _Buffer, stats: dict[str, Any]) -> None:
    """Load buffered rows via dlt and checkpoint the offset (main thread only)."""
    if not buf.rows:
        return
    try:
        pipeline.run(_messages_dlt_resource(buf.rows))
    except Exception:
        # Most commonly a corrupt pending load package left by an interrupted
        # previous run (FileNotFoundError on load/normalized/<id>/new_jobs).
        # Drop pending packages and retry once. If the retry also fails (e.g. a
        # real DB error), the exception propagates and aborts the drain — the
        # job stays 'running' and is swept to 'pending' on the next tick (merge
        # dedup on PK makes a re-fetch idempotent, so no data loss).
        stats["flush_failures"] += 1
        pipeline.drop_pending_packages()
        pipeline.run(_messages_dlt_resource(buf.rows))
    stats["rows_loaded"] += len(buf.rows)
    _checkpoint(conn, key, buf.offset)
    buf.rows.clear()


# --------------------------------------------------------------------------- #
# Worker (pure HTTP — no DB, no dlt)
# --------------------------------------------------------------------------- #
def fetch_messages_worker(
    job: ClaimedJob,
    base_url: str,
    page_access_tokens: dict,
    page_semaphores: dict,
    results_q: "queue.Queue",
) -> None:
    """Paginate one conversation's messages; push Chunk(s) then a Terminal."""
    page_id = str(job["page_id"])
    conv_id = str(job["conversation_id"])
    key = JobKey(page_id, conv_id)

    token = page_access_tokens.get(page_id)
    if not token:
        results_q.put(Terminal(key, "dead", page_fatal=True, error="missing page access token"))
        return

    url = f"{base_url}/{MSG_ENDPOINT.lstrip('/').replace('{page_id}', page_id).replace('{conversation_id}', conv_id)}"
    semaphore = page_semaphores[page_id]
    sync_ts = datetime.now(timezone.utc).isoformat()
    offset = int(job["current_count"])
    deadline = time.monotonic() + MAX_JOB_SECONDS

    try:
        for _ in range(MAX_JOB_ITERATIONS):
            if time.monotonic() >= deadline:
                results_q.put(Terminal(key, "pending", error="job_timeout", offset_after=offset))
                return

            with semaphore:
                data = requests.get(
                    url, params={"page_access_token": token, "current_count": offset}
                ).json()

            if not isinstance(data, dict) or data.get("success") is False:
                err_code = data.get("error_code") if isinstance(data, dict) else None
                err_msg = (data.get("message", "") if isinstance(data, dict) else "") or "unknown"
                fatal = _is_page_fatal_error(err_code, err_msg)
                results_q.put(
                    Terminal(
                        key,
                        "dead" if fatal else "pending",
                        retryable=not fatal,
                        page_fatal=fatal,
                        error=f"api_error code={err_code}: {err_msg}",
                        offset_after=offset,
                    )
                )
                return

            batch = data.get("messages") or []
            if not batch:
                break

            results_q.put(
                Chunk(
                    key,
                    offset + len(batch),
                    [
                        {**m, "conversation_id": conv_id, "page_id": page_id, "_db_updated_at": sync_ts}
                        for m in batch
                    ],
                )
            )
            offset += len(batch)
            if len(batch) < MSG_PAGE_SIZE:
                break
        else:
            # Loop exhausted without a natural break — pagination guard tripped.
            results_q.put(Terminal(key, "pending", error="job_iteration_limit", offset_after=offset))
            return

        results_q.put(Terminal(key, "done", offset_after=offset))
    except Exception as exc:  # noqa: BLE001 - a worker must always emit a terminal
        results_q.put(
            Terminal(key, "pending", retryable=True, error=repr(exc), offset_after=offset)
        )


# --------------------------------------------------------------------------- #
# Public ops
# --------------------------------------------------------------------------- #
def enqueue_message_jobs(conn) -> dict[str, Any]:
    """Top up the queue from raw_pancake.conversations (message_count > 0).

    New conversations become ``pending`` (``current_count=0``). Existing ``done``
    jobs whose ``message_count`` grew drop back to ``pending`` while keeping
    ``current_count``, so the worker resumes from its offset. Returns counts.
    """
    ensure_queue_schema(conn)
    with conn.cursor() as cur:
        cur.execute(f"SELECT to_regclass('{PANCAKE_DATASET_NAME}.conversations')")
        if cur.fetchone()[0] is None:
            conn.commit()
            return {"enqueued": 0, "pending": 0, "total": 0, "note": "conversations table not yet loaded"}

        cur.execute(_ENQUEUE_SQL)
        enqueued = cur.fetchone()[0]
        cur.execute(_ENROLL_PAGES_SQL)
        cur.execute(_COUNT_STATUS_SQL, ("pending",))
        pending = cur.fetchone()[0]
        cur.execute(f"SELECT count(*) FROM {QUEUE_QUALIFIED}")
        total = cur.fetchone()[0]
    conn.commit()
    return {"enqueued": enqueued, "pending": pending, "total": total, "note": ""}


def drain_message_jobs(
    log: logging.Logger,
    conn,
    pipeline,
    page_access_tokens: dict,
    base_url: str,
) -> dict[str, Any]:
    """Claim pending jobs, fetch messages concurrently, batch-load + checkpoint.

    Runs batch-by-batch within ``DRAIN_BUDGET_SECONDS``. Each batch fully drains
    its claimed jobs before the next claim; per-job time/iteration guards bound
    the slowest job. A run crash leaves jobs ``running`` → the next tick's
    sweeper reclaims them and resumes from the persisted ``current_count``.
    """
    ensure_queue_schema(conn)
    swept = _sweep_stuck(conn)
    if swept:
        log.info("Sweeper reclaimed %d stuck jobs", swept)

    stats = _new_stats(swept)
    deadline = time.monotonic() + DRAIN_BUDGET_SECONDS

    # Drop any pending dlt load packages left by a previous interrupted run.
    # The pancake_messages pipeline has no incremental cursor (the queue's
    # current_count tracks progress, not dlt state), so dropping load packages
    # is always safe. Without this, a single interrupted run poisons every
    # subsequent run: dlt tries to re-load the corrupt pending package and fails
    # with FileNotFoundError on load/normalized/<id>/new_jobs.
    if pipeline.has_pending_data:
        log.warning(
            "Dropping pending dlt load packages in pipeline '%s' — a previous "
            "drain was likely interrupted mid-flight.",
            pipeline.pipeline_name,
        )
        pipeline.drop_pending_packages()
        stats["pending_packages_dropped"] = 1

    while time.monotonic() < deadline:
        claimed = _claim_batch(conn, CLAIM_BATCH_SIZE)
        if not claimed:
            break
        stats["claimed"] += len(claimed)
        stats["batches"] += 1
        _process_batch(conn, pipeline, claimed, page_access_tokens, base_url, stats)

    stats["pending_remaining"] = _count_status(conn, "pending")
    blocked = _blocked_pages(conn)
    if blocked:
        stats["blocked_pages"] = blocked
        log.warning(
            "%d page(s) blocked by circuit breaker: %s",
            len(blocked),
            ", ".join(b["page_id"] for b in blocked),
        )
    return stats


def _new_stats(swept: int = 0) -> dict[str, Any]:
    return {
        "claimed": 0,
        "done": 0,
        "retried": 0,
        "dead": 0,
        "rows_loaded": 0,
        "batches": 0,
        "swept": swept,
        "pages_blocked": 0,
        "flush_failures": 0,
        "pending_packages_dropped": 0,
    }


def _process_batch(
    conn,
    pipeline,
    jobs: list[ClaimedJob],
    page_access_tokens: dict,
    base_url: str,
    stats: dict[str, Any],
) -> None:
    """Drain one claimed batch: fan out workers, load chunks, finalize terminals.

    Load failures are isolated per-job: a single job whose rows dlt cannot load
    is marked ``pending`` (+1 attempt) and the batch continues with the
    remaining jobs. Only after ``MAX_CONSECUTIVE_FLUSH_FAILURES`` consecutive
    failures does the drain abort — that signals a DB outage, not bad data.
    """
    # One semaphore per page caps PER_PAGE_CONCURRENCY even when many jobs in the
    # batch share the same page_access_token.
    semaphores: dict[str, threading.Semaphore] = {
        str(j["page_id"]): threading.Semaphore(PER_PAGE_CONCURRENCY) for j in jobs
    }
    results: "queue.Queue" = queue.Queue()
    buffers: dict[JobKey, _Buffer] = {}
    dead_jobs: set[JobKey] = set()
    consecutive_failures = 0
    pending = len(jobs)

    def _safe_flush(key: JobKey, buf: _Buffer) -> bool:
        """Flush via dlt; on persistent failure isolate the job.

        Returns True on success (resets the consecutive-failure counter),
        False when the job was isolated as ``pending`` (+1 attempt). Re-raises
        after MAX_CONSECUTIVE_FLUSH_FAILURES to abort the drain — that's a DB
        outage, and the remaining jobs are swept to pending on the next tick.
        """
        nonlocal consecutive_failures
        try:
            _flush_buffer(conn, pipeline, key, buf, stats)
            consecutive_failures = 0
            return True
        except Exception as exc:
            consecutive_failures += 1
            if consecutive_failures >= MAX_CONSECUTIVE_FLUSH_FAILURES:
                raise  # DB likely down — abort; jobs stay 'running' → swept to pending
            _log.warning(
                "Load failed for job %s after retry — isolating "
                "(consecutive_failures=%d/%d): %s",
                key, consecutive_failures, MAX_CONSECUTIVE_FLUSH_FAILURES, exc,
            )
            buf.rows.clear()
            dead_jobs.add(key)
            _finalize_job(
                conn,
                Terminal(key, "pending", retryable=True, error=f"load_failure: {exc!r}"),
                stats,
            )
            return False

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for job in jobs:
            pool.submit(fetch_messages_worker, job, base_url, page_access_tokens, semaphores, results)

        while pending:
            try:
                item = results.get(timeout=5)
            except queue.Empty:
                continue

            if isinstance(item, Chunk):
                if item.job_key in dead_jobs:
                    continue
                buf = buffers.setdefault(item.job_key, _Buffer())
                buf.rows.extend(item.rows)
                buf.offset = item.offset_after
                if len(buf.rows) >= LOAD_BATCH:
                    if not _safe_flush(item.job_key, buf):
                        pending -= 1
                continue

            # Terminal for a job already isolated by _safe_flush (mid-Chunk flush
            # failure). pending was already decremented at the isolation point —
            # do NOT decrement again, or the loop exits early and drops jobs.
            if item.job_key in dead_jobs:
                buffers.pop(item.job_key, None)
                continue
            tail = buffers.pop(item.job_key, None)
            if tail is not None:
                if not _safe_flush(item.job_key, tail):
                    pending -= 1
                    continue
            _finalize_job(conn, item, stats)
            pending -= 1


__all__ = [
    "Chunk",
    "JobKey",
    "Terminal",
    "build_messages_pipeline",
    "drain_message_jobs",
    "enqueue_message_jobs",
    "ensure_queue_schema",
    "fetch_messages_worker",
    "page_progress",
    "refresh_edit_jobs",
]
