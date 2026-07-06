from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(("ingestion", "pancake", resource_name) for resource_name in resource_names)


def _backfill_asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(("ingestion", "pancake", "backfill", resource_name) for resource_name in resource_names)


PANCAKE_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="conversations_customers_batch",
            asset_paths=_asset_paths("conversations", "page_customers"),
            description="Refresh Pancake conversations and page customers (incremental by updated_at)",
            cadence="hourly",
            cron_schedule="5 * * * *",
            schedule_token="hourly",
            schedule_description="Run Pancake conversations and page customers hourly at minute 5",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="message_jobs_drain",
            asset_paths=_asset_paths("message_jobs_drain"),
            description=(
                "Drain the pancake_sync.message_jobs queue: claim (SKIP LOCKED), "
                "fetch messages concurrently, batch-load via dlt, checkpoint "
                "current_count. Selection auto-includes the upstream enqueue asset."
            ),
            cadence="5min",
            cron_schedule="*/5 * * * *",
            schedule_token="5min",
            schedule_description="Drain Pancake message jobs every 5 minutes",
            max_runtime_seconds=240,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="message_jobs_refresh_edits",
            asset_paths=_asset_paths("message_jobs_refresh_edits"),
            description=(
                "Re-queue done message jobs whose conversation changed since last "
                "pull (edits/removals). Throttled; full re-pull per job."
            ),
            cadence="daily",
            cron_schedule="30 18 * * *",
            schedule_token="daily_18utc",
            schedule_description="Refresh Pancake message edits daily at 01:30 ICT (18:30 UTC)",
            max_runtime_seconds=600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="pages_users_tags_batch",
            asset_paths=_asset_paths("page_users", "tags"),
            description="Refresh Pancake pages, users, and tags (full sync)",
            cadence="daily",
            cron_schedule="0 18 * * *",
            schedule_token="daily_18utc",
            schedule_description="Run Pancake pages, users, and tags daily at 01:00 ICT (18:00 UTC)",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="conversations_backfill",
            asset_paths=_backfill_asset_paths("conversations"),
            description="Manual monthly backfill of historical conversations (partitioned). Materialize partitions 2020-01 to 2026-06. Per-partition pipeline-name isolation.",
            cadence="manual",
            max_runtime_seconds=7200,
        ),
    )
)


__all__ = ["PANCAKE_EXECUTION_UNITS"]
