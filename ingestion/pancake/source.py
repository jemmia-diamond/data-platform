from __future__ import annotations

import json
import os
from typing import Optional

import dlt
import requests

from .resources import TABLE_SPECS, build_conversations, build_table_resource

DEFAULT_PANCAKE_BASE_URL = "https://pages.fm/api"
DEFAULT_START_DATE = "2026-07-01T00:00:00+00:00"

_PAT_CONFIG_PREFIX = "PANCAKE_PATS_CONFIG_"
_PAT_ENV_PREFIX = "SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__"


def load_page_access_tokens() -> dict:
    """Resolve Pancake page access tokens: env vars first, Infisical fallback. """
    tokens = {
        key[len(_PAT_ENV_PREFIX):]: value
        for key, value in os.environ.items()
        if key.startswith(_PAT_ENV_PREFIX) and value
    }
    if tokens:
        return tokens
    return _load_page_access_tokens_from_infisical()


def _load_page_access_tokens_from_infisical() -> dict:
    response = requests.get(
        f"{os.environ['INFISICAL_HOST']}/api/v3/secrets/raw",
        headers={"Authorization": f"Bearer {os.environ['PUBLIC_INFISICAL_TOKEN']}"},
        params={
            "workspaceId": os.environ["INFISICAL_WORKSPACE_ID"],
            "environment": os.environ.get("INFISICAL_ENVIRONMENT", "prod"),
            "secretPath": os.environ.get("INFISICAL_SECRET_PATH", "/commons/public"),
        },
        timeout=30,
    )
    response.raise_for_status()

    tokens: dict = {}
    for secret in response.json()["secrets"]:
        if secret["secretKey"].startswith(_PAT_CONFIG_PREFIX) and secret["secretValue"]:
            tokens.update(json.loads(secret["secretValue"]))
    return tokens


@dlt.source(name="pancake")
def pancake_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    page_access_tokens: Optional[dict] = None,
):
    """Build the Pancake source across all Facebook pages.

    ``page_access_tokens`` is resolved lazily from Infisical when not supplied,
    so callers that only need the source for asset-key derivation can pass a
    placeholder to keep import time off the network.
    """
    if page_access_tokens is None:
        page_access_tokens = load_page_access_tokens()

    resources = [
        build_table_resource(spec, base_url, page_access_tokens, start_date, end_date)
        for spec in TABLE_SPECS
    ]
    resources.append(build_conversations(base_url, page_access_tokens, start_date, end_date))
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
