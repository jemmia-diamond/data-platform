from __future__ import annotations

import json
import os
from typing import Optional

import dlt

from .resources import TABLE_SPECS, build_conversations, build_pages, build_table_resource

DEFAULT_PANCAKE_BASE_URL = "https://pages.fm/api"
DEFAULT_START_DATE = "2026-07-01T00:00:00+00:00"

PAT_CONFIG_PREFIX = "PANCAKE_PATS_CONFIG_"


def load_page_access_tokens() -> dict[str, str]:
    """Resolve Pancake page access tokens from environment variables."""
    tokens: dict[str, str] = {}
    for key, value in os.environ.items():
        if not key.startswith(PAT_CONFIG_PREFIX) or not value:
            continue
        try:
            page_tokens = json.loads(value)
        except json.JSONDecodeError as error:
            raise RuntimeError(
                f"Environment variable {key} is not valid JSON: {error}"
            ) from error
        tokens.update(page_tokens)
    if not tokens:
        raise RuntimeError(
            "No Pancake page access tokens found."
        )
    return tokens


@dlt.source(name="pancake")
def pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    page_access_tokens: Optional[dict] = None,
):
    """Build the Pancake source across all Facebook pages.

    ``page_access_tokens`` is resolved lazily from environment variables when
    not supplied, so callers that only need the source for asset-key
    derivation can pass a placeholder to avoid requiring tokens at import time.
    """
    if page_access_tokens is None:
        page_access_tokens = load_page_access_tokens()

    resources = [
        build_table_resource(spec, base_url, page_access_tokens, start_date, end_date)
        for spec in TABLE_SPECS
    ]
    resources.append(build_conversations(base_url, page_access_tokens, start_date, end_date))
    resources.append(build_pages(base_url))
    return tuple(resources)


def build_pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: str = DEFAULT_PANCAKE_BASE_URL,
    page_access_tokens: Optional[dict] = None,
):
    """Helper for creating a Pancake source with optional explicit overrides."""
    kwargs: dict = {
        "start_date": start_date,
        "end_date": end_date,
        "base_url": base_url,
    }
    if page_access_tokens is not None:
        kwargs["page_access_tokens"] = page_access_tokens
    return pancake_source(**kwargs)


__all__ = [
    "DEFAULT_PANCAKE_BASE_URL",
    "DEFAULT_START_DATE",
    "build_pancake_source",
    "load_page_access_tokens",
]
