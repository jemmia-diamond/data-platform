from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.frappe import (
    DEFAULT_FRAPPE_BASE_URL,
    DEFAULT_START_DATE,
    build_frappe_pipeline,
    build_frappe_source,
)

from .translator import FrappeDagsterDltTranslator


class FrappeIngestionConfig(Config):
    """Runtime config exposed in Dagster for Frappe loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False
    api_auth_scheme: str = "token"
    verify: bool = True


def _selected_frappe_resources(context: AssetExecutionContext) -> list[str]:
    return sorted(
        {
            key.path[3]
            for key in context.selected_asset_keys
            if len(key.path) >= 4
            and key.path[0] == "ingestion"
            and key.path[1] == "frappe"
            and key.path[2] == "erpnext"
        }
    )


@dlt_assets(
    dlt_source=build_frappe_source(
        base_url=DEFAULT_FRAPPE_BASE_URL,
        api_key="[ENCRYPTION_KEY]",  # override via env vars
        api_secret="[ENCRYPTION_KEY]",  # override via env vars
    ),
    dlt_pipeline=build_frappe_pipeline(),
    name="frappe_dlt_assets",
    dagster_dlt_translator=FrappeDagsterDltTranslator(),
)
def frappe_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: FrappeIngestionConfig,
):
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_frappe_resources(context)

    source = build_frappe_source(
        start_date=config.start_date,
        end_date=config.end_date,
        api_auth_scheme=config.api_auth_scheme,
        verify=config.verify,
    )

    if not selected_resources:
        context.log.warning("No selected Frappe resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=source,
            dlt_pipeline=build_frappe_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"frappe_erpnext_{resource_name}"
        context.log.info(
            f"Running Frappe resource={resource_name} "
            f"with start_date={config.start_date} end_date={config.end_date} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=source.with_resources(resource_name),
            dlt_pipeline=build_frappe_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["FrappeIngestionConfig", "frappe_assets"]
