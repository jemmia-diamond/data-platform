from __future__ import annotations

from typing import Optional

import dlt

from .resources import build_orders_resource

DEFAULT_HARAVAN_BASE_URL = "https://apis.haravan.com/com/"
DEFAULT_START_DATE = "2026-01-01T00:00:00.000Z"


@dlt.source(name="haravan")
def haravan_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    api_token: str = dlt.secrets.value,
):
    """Build the Haravan source and let dlt resolve config from env vars."""
    return (
        build_orders_resource(
            base_url=base_url,
            api_token=api_token,
            start_date=start_date,
            end_date=end_date,
        ),
    )


def build_haravan_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    api_token: Optional[str] = None,
):
    """Helper for creating a Haravan source with optional explicit overrides."""
    source_kwargs = {
        "start_date": start_date,
        "end_date": end_date,
    }
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if api_token is not None:
        source_kwargs["api_token"] = api_token
    return haravan_source(**source_kwargs)


__all__ = ["DEFAULT_HARAVAN_BASE_URL", "DEFAULT_START_DATE", "build_haravan_source"]
