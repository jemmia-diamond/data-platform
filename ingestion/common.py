from __future__ import annotations

from datetime import datetime, timezone

from dlt.extract.resource import DltResource

RAW_UPDATED_AT_COLUMN = "_db_updated_at"


def sync_timestamp() -> str:
    """Return the UTC timestamp marking when the current sync run started.

    Returns:
        The current UTC time as an ISO-8601 string, used to stamp the
        ``_db_updated_at`` audit column on every ingested record.
    """
    return datetime.now(timezone.utc).isoformat()


def apply_raw_hints(resource: DltResource) -> DltResource:
    """Type the audit column and flatten nested tables on a raw resource.

    Args:
        resource: The dlt resource to annotate in place.

    Returns:
        The same resource, with ``_db_updated_at`` declared as a non-nullable
        timestamp and child-table nesting disabled.
    """
    resource.apply_hints(
        columns={RAW_UPDATED_AT_COLUMN: {"data_type": "timestamp", "nullable": False}}
    )
    resource.max_table_nesting = 0
    return resource


__all__ = ["RAW_UPDATED_AT_COLUMN", "sync_timestamp", "apply_raw_hints"]
