from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.haravan import (
    DEFAULT_HARAVAN_BASE_URL,
    DEFAULT_START_DATE,
    build_haravan_pipeline,
    build_haravan_source,
)

from .translator import IngestionDagsterDltTranslator


class HaravanIngestionConfig(Config):
    """Runtime config exposed in Dagster for Haravan loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False


@dlt_assets(
    dlt_source=build_haravan_source(
        base_url=DEFAULT_HARAVAN_BASE_URL,
        api_token="[ENCRYPTION_KEY]", # override by config
    ),
    dlt_pipeline=build_haravan_pipeline(),
    name="haravan_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def haravan_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: HaravanIngestionConfig,
):
    """Run Haravan ingestion through dagster-dlt."""
    context.log.info(
        f"Running Haravan sync with start_date={config.start_date} "
        f"end_date={config.end_date} full_refresh={config.full_refresh}"
    )

    refresh = "drop_data" if config.full_refresh else None

    yield from dlt.run(
        context=context,
        dlt_source=build_haravan_source(
            start_date=config.start_date,
            end_date=config.end_date,
        ),
        dlt_pipeline=build_haravan_pipeline(),
        refresh=refresh,
    ).fetch_row_count()


__all__ = ["HaravanIngestionConfig", "haravan_assets"]
