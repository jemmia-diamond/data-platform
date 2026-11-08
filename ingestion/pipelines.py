from __future__ import annotations

import dlt
from dlt.common.schema.typing import TLoaderReplaceStrategy
from dlt.pipeline.pipeline import Pipeline


def build_dlt_pipeline(
    connector_name: str,
    dataset_name: str | None = None,
    replace_strategy: TLoaderReplaceStrategy | None = None,
) -> Pipeline:
    """Create a dlt pipeline using native destination configuration.

    `replace_strategy` only affects tables loaded with write_disposition="replace". dlt's
    postgres default, truncate-and-insert, empties the table before inserting and isn't atomic.
    """
    return dlt.pipeline(
        pipeline_name=connector_name,
        destination=dlt.destinations.postgres(replace_strategy=replace_strategy)
        if replace_strategy
        else "postgres",
        dataset_name=dataset_name or f"raw_{connector_name}",
        dev_mode=False,
        progress="log",
    )


__all__ = ["build_dlt_pipeline"]
