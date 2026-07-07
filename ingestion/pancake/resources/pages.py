from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Iterator, Optional

import dlt
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests

_PAGES_ENDPOINT = "/v1/pages"
_USER_ACCESS_TOKEN_ENV = "SOURCES__PANCAKE__USER_ACCESS_TOKEN"
_PAGES_RESPONSE_KEY = "categorized"


def _apply_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(columns={"_db_updated_at": {"data_type": "timestamp", "nullable": False}})
    resource.max_table_nesting = 0
    return resource


def load_user_access_token() -> str:
    """Resolve the Pancake user (master) access token from the environment."""
    token = os.environ.get(_USER_ACCESS_TOKEN_ENV)
    if not token:
        raise RuntimeError(
            f"{_USER_ACCESS_TOKEN_ENV} is not set; the Pancake 'page' resource "
            "requires the user access token."
        )
    return token


def build_pages(base_url: str, user_access_token: Optional[str] = None) -> DltResource:
    """Build the ``page`` resource listing every page the user can access."""
    sync_ts = datetime.now(timezone.utc).isoformat()

    @dlt.resource(name="page", primary_key="id", write_disposition="merge")
    def page() -> Iterator[dict]:
        """Yield all Pancake pages the user can access."""
        token = user_access_token or load_user_access_token()
        url = f"{base_url}/{_PAGES_ENDPOINT.lstrip('/')}"
        data = requests.get(url, params={"access_token": token}).json()

        if isinstance(data, dict) and data.get("success") is False:
            raise RuntimeError(
                f"Pancake {_PAGES_ENDPOINT} request failed: "
                f"error_code={data.get('error_code')}"
            )

        categorized = (data.get(_PAGES_RESPONSE_KEY) if isinstance(data, dict) else None) or {}
        for group in categorized.values():
            if not isinstance(group, list):
                continue
            for item in group:
                if isinstance(item, dict):
                    yield {**item, "_db_updated_at": sync_ts}

    return _apply_hints(page)


__all__ = ["build_pages", "load_user_access_token"]
