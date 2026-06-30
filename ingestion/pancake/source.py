from __future__ import annotations

import os
from typing import Optional

import dlt

from .resources import TABLE_SPECS, build_conversations_and_messages, build_table_resource

DEFAULT_PANCAKE_BASE_URL = "https://pages.fm/api"
DEFAULT_START_DATE = "2026-06-28T00:00:00+00:00"

_PAT_ENV_PREFIX = "SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__"


def _load_page_access_tokens() -> dict:
    """Read page access tokens from env vars.

    Scans for ``SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__<page_id>`` and returns a
    mapping of page_id to token. PATs do not expire; only update when adding a
    new page.
    """
    return {
        key[len(_PAT_ENV_PREFIX):]: value
        for key, value in os.environ.items()
        if key.startswith(_PAT_ENV_PREFIX) and value
    }


@dlt.source(name="pancake")
def pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    page_access_tokens: Optional[dict] = None,
):
    """Build the Pancake source across all Facebook pages."""
    if page_access_tokens is None:
        page_access_tokens = _load_page_access_tokens()

    resources = [
        build_table_resource(spec, base_url, page_access_tokens, start_date, end_date)
        for spec in TABLE_SPECS
    ]
    resources.extend(
        build_conversations_and_messages(base_url, page_access_tokens, start_date, end_date)
    )
    return tuple(resources)


def build_pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    page_access_tokens: Optional[dict] = None,
):
    """Helper for creating a Pancake source with optional explicit overrides."""
    kwargs: dict = {"start_date": start_date, "end_date": end_date}
    if base_url is not None:
        kwargs["base_url"] = base_url
    if page_access_tokens is not None:
        kwargs["page_access_tokens"] = page_access_tokens
    return pancake_source(**kwargs)


__all__ = [
    "DEFAULT_PANCAKE_BASE_URL",
    "DEFAULT_START_DATE",
    "build_pancake_source",
]
