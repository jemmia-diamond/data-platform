"""
Dagster translator customizations for dlt assets.
"""

from dagster import AssetKey
from dagster_dlt import DagsterDltTranslator
from dagster_dlt.translator import DltResourceTranslatorData


class IngestionDagsterDltTranslator(DagsterDltTranslator):
    """Keep dlt asset keys predictable across connectors."""

    def get_asset_spec(self, data: DltResourceTranslatorData):
        spec = super().get_asset_spec(data)
        deps = []
        if data.resource.is_transformer:
            pipe = data.resource._pipe  # noqa: SLF001
            while pipe.has_parent:
                pipe = pipe.parent
            deps = [AssetKey(["ingestion", data.resource.source_name, pipe.name])]

        return spec.replace_attributes(
            key=AssetKey(["ingestion", data.resource.source_name, data.resource.name]),
            deps=deps,
            group_name="ingestion",
        )


__all__ = ["IngestionDagsterDltTranslator"]
