from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(("ingestion", "pancake", resource_name) for resource_name in resource_names)


PANCAKE_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="pancake",
            unit="conversations_customers_batch",
            asset_paths=_asset_paths("conversations", "messages", "page_customers"),
            description="Refresh Pancake conversations and page customers (incremental by updated_at)",
            cadence="5m",
            cron_schedule="*/5 * * * *",
            schedule_token="every_5m",
            schedule_description="Run Pancake conversations and page customers every 5 minutes",
            max_runtime_seconds=480,
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
    )
)


__all__ = ["PANCAKE_EXECUTION_UNITS"]
