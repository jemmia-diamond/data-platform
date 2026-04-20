from __future__ import annotations

import dlt
from dlt.pipeline.pipeline import Pipeline


def build_dlt_pipeline(connector_name: str, dataset_name: str | None = None) -> Pipeline:
    """Create a dlt pipeline using native destination configuration."""
    return dlt.pipeline(
        pipeline_name=connector_name,
        destination="postgres",
        dataset_name=dataset_name or f"raw_{connector_name}",
        dev_mode=False,
        progress="log",
    )


__all__ = ["build_dlt_pipeline"]
