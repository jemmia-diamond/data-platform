from __future__ import annotations

from typing import Optional

import dlt

from .resources import build_all_resources

DEFAULT_START_DATE = "2024-01-01T00:00:00+00:00"


@dlt.source(name="pancake")
def pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    user_access_token: str = dlt.secrets.value,
):
    """Build the Pancake source. Resources are declared in tables_to_sync.yaml."""
    return tuple(
        build_all_resources(
            base_url=base_url,
            user_access_token=user_access_token,
            start_date=start_date,
            end_date=end_date,
        )
    )


def build_pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    user_access_token: Optional[str] = None,
):
    kwargs: dict = {"start_date": start_date, "end_date": end_date}
    if base_url is not None:
        kwargs["base_url"] = base_url
    if user_access_token is not None:
        kwargs["user_access_token"] = user_access_token
    return pancake_source(**kwargs)


__all__ = ["DEFAULT_START_DATE", "build_pancake_source"]
