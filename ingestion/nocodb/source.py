from __future__ import annotations

from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from .resources import TABLE_SPECS, build_table_resource

DEFAULT_NOCODB_BASE_URL = "https://workspace.jemmia.vn/api/v2"
DEFAULT_START_DATE = "2026-04-01T00:00:00.000Z"


@dlt.source(name="nocodb")
def nocodb_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    api_token: str = dlt.secrets.value,
) -> tuple[DltResource, ...]:
    return tuple(
        build_table_resource(
            spec=spec,
            base_url=base_url,
            api_token=api_token,
            start_date=start_date,
            end_date=end_date,
        )
        for spec in TABLE_SPECS
    )

def build_nocodb_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    api_token: Optional[str] = None,
):
    """Helper for creating a NocoDB source with optional explicit overrides."""
    source_kwargs = {
        "start_date": start_date,
        "end_date": end_date,
    }
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if api_token is not None:
        source_kwargs["api_token"] = api_token
    return nocodb_source(**source_kwargs)


__all__ = [
    "DEFAULT_NOCODB_BASE_URL",
    "DEFAULT_START_DATE",
    "build_nocodb_source",
]
