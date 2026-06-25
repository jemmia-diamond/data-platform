"""
Pancake dlt source package.
"""

from ingestion.pipelines import build_dlt_pipeline
from ingestion.utils import get_last_sync_ts

from .resources.builder import load_table_specs
from .source import (
    DEFAULT_START_DATE,
    build_pancake_source,
)

PANCAKE_PIPELINE_NAME = "pancake"
PANCAKE_DATASET_NAME = "raw_pancake"


def build_pancake_pipeline(pipeline_name: str = PANCAKE_PIPELINE_NAME):
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=PANCAKE_DATASET_NAME,
    )


def get_pancake_start_date(table: str | None = None, fallback: str = DEFAULT_START_DATE) -> str:
    """Return MAX(_db_updated_at) for one incremental table, or min across all if table is None.

    Falls back to `fallback` (default: DEFAULT_START_DATE) when the table doesn't exist yet.
    """
    if table is not None:
        return get_last_sync_ts(schema=PANCAKE_DATASET_NAME, table=table, fallback=fallback)
    incremental_tables = [s.name for s in load_table_specs() if s.sync_type == "incremental"]
    if not incremental_tables:
        return fallback
    return min(
        get_last_sync_ts(schema=PANCAKE_DATASET_NAME, table=t, fallback=fallback)
        for t in incremental_tables
    )


__all__ = [
    "DEFAULT_START_DATE",
    "PANCAKE_DATASET_NAME",
    "PANCAKE_PIPELINE_NAME",
    "build_pancake_pipeline",
    "build_pancake_source",
    "get_pancake_start_date",
]
