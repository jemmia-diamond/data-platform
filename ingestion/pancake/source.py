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
    page_access_tokens: dict = dlt.secrets.value,
):
    """Build the Pancake source. Resources are declared in tables_to_sync.yaml.

    page_access_tokens: {page_id: page_access_token}, loaded from:
      - .dlt/secrets.toml  →  [sources.pancake.page_access_tokens]
      - env vars           →  SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__<page_id>=<pat>
    PATs do not expire — only update when adding a new page.
    """
    return tuple(
        build_all_resources(
            base_url=base_url,
            page_access_tokens=page_access_tokens,
            start_date=start_date,
            end_date=end_date,
        )
    )


def build_pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    page_access_tokens: Optional[dict] = None,
):
    kwargs: dict = {"start_date": start_date, "end_date": end_date}
    if base_url is not None:
        kwargs["base_url"] = base_url
    if page_access_tokens is not None:
        kwargs["page_access_tokens"] = page_access_tokens
    return pancake_source(**kwargs)


__all__ = ["DEFAULT_START_DATE", "build_pancake_source"]
