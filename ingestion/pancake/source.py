from __future__ import annotations

import os
from typing import Optional

import dlt

from .resources import build_all_resources

DEFAULT_START_DATE = "2018-01-01T00:00:00+00:00"

_PAT_ENV_PREFIX = "SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__"


def _load_page_access_tokens_from_env() -> dict:
    """Read PATs from SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__<page_id> env vars."""
    return {
        k[len(_PAT_ENV_PREFIX):]: v
        for k, v in os.environ.items()
        if k.startswith(_PAT_ENV_PREFIX) and v
    }


@dlt.source(name="pancake")
def pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    page_access_tokens: Optional[dict] = None,
):
    """Build the Pancake source. Resources are declared in tables_to_sync.yaml.

    page_access_tokens: loaded from env vars
      SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__<page_id>=<token>
    PATs do not expire — only update when adding a new page.
    """
    if not page_access_tokens:
        page_access_tokens = _load_page_access_tokens_from_env()

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
