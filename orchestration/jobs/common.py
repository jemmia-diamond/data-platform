from dagster import AssetKey, AssetSelection, define_asset_job

from ..catalogs.common import ExecutionUnitSpec


def build_asset_selection(*asset_paths: tuple[str, ...]) -> AssetSelection:
    return AssetSelection.keys(*[AssetKey(list(asset_path)) for asset_path in asset_paths])


def build_job_definition(spec: ExecutionUnitSpec):
    selection = build_asset_selection(*spec.asset_paths)
    tags = spec.dagster_tags

    return define_asset_job(
        name=spec.job_name,
        selection=selection,
        description=spec.description,
        tags=tags,
        run_tags=tags,
    )


def build_jobs_by_name(specs: tuple[ExecutionUnitSpec, ...]) -> dict[str, object]:
    return {spec.job_name: build_job_definition(spec) for spec in specs}


__all__ = ["build_asset_selection", "build_job_definition", "build_jobs_by_name"]
