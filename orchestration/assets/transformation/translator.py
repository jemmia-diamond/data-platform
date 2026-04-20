from pathlib import Path
from typing import Any, Mapping

from dagster import AssetKey
from dagster_dbt import DagsterDbtTranslator


class TransformationDagsterDbtTranslator(DagsterDbtTranslator):
    """Map dbt assets to a folder structure that mirrors the project layout."""

    def get_asset_key(self, dbt_resource_props: Mapping[str, Any]) -> AssetKey:
        original_file_path = Path(dbt_resource_props["original_file_path"])
        path_parts = list(original_file_path.parts)

        if path_parts and path_parts[0] == "models":
            path_parts = path_parts[1:]

        folder_parts = path_parts[:-1]
        resource_type = dbt_resource_props["resource_type"]

        if resource_type == "source":
            return AssetKey(
                [
                    "transformation",
                    *folder_parts,
                    "sources",
                    dbt_resource_props["source_name"],
                    dbt_resource_props["name"],
                ]
            )

        layer = dbt_resource_props.get("schema") or (folder_parts[0] if folder_parts else None)
        remaining_parts = folder_parts[1:] if folder_parts else []

        asset_path = ["transformation"]
        if layer:
            asset_path.append(layer)
        asset_path.extend(remaining_parts)
        asset_path.append(dbt_resource_props["name"])

        return AssetKey(asset_path)

    def get_group_name(self, dbt_resource_props: Mapping[str, Any]) -> str | None:
        return "transformation"


__all__ = ["TransformationDagsterDbtTranslator"]
