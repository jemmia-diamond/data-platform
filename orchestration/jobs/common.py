from dagster import AssetKey, AssetSelection, define_asset_job

from ..tags import build_dagster_tags


def build_asset_selection(*asset_paths: tuple[str, ...]) -> AssetSelection:
    return AssetSelection.keys(*[AssetKey(list(asset_path)) for asset_path in asset_paths])


def define_tagged_asset_job(
    *,
    name: str,
    selection: AssetSelection,
    description: str,
    layer: str,
    tool: str,
    system: str,
    family: str,
    cadence: str,
):
    tags = build_dagster_tags(
        layer=layer,
        tool=tool,
        system=system,
        family=family,
        cadence=cadence,
    )

    return define_asset_job(
        name=name,
        selection=selection,
        description=description,
        tags=tags,
        run_tags=tags,
    )


__all__ = ["build_asset_selection", "define_tagged_asset_job"]
