from __future__ import annotations

import logging
import time
from typing import Optional

import requests

DEFAULT_TIMEOUT = 60
MAX_RETRIES = 3
BACKOFF_BASE_SECONDS = 1.0
BACKOFF_MAX_SECONDS = 30.0
PAGE_SLEEP_SECONDS = 1.0

logger = logging.getLogger(__name__)


def get_with_retry(
    url: str,
    params: Optional[dict] = None,
) -> requests.Response:
    """GET request with exponential backoff on 429 / 5xx."""
    for attempt in range(MAX_RETRIES + 1):
        response = requests.get(url, params=params, timeout=DEFAULT_TIMEOUT)

        if response.status_code == 429:
            if attempt >= MAX_RETRIES:
                response.raise_for_status()
            retry_after_raw = response.headers.get("Retry-After")
            try:
                wait = float(retry_after_raw) if retry_after_raw else None
            except ValueError:
                wait = None
            wait = wait or min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (2**attempt))
            logger.warning("Pancake rate limit hit. Retrying in %.1fs (%s/%s).", wait, attempt + 1, MAX_RETRIES + 1)
            time.sleep(wait)
            continue

        if response.status_code >= 500:
            if attempt >= MAX_RETRIES:
                response.raise_for_status()
            wait = min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (2**attempt))
            logger.warning("Pancake server error %s. Retrying in %.1fs.", response.status_code, wait)
            time.sleep(wait)
            continue

        response.raise_for_status()
        return response

    raise RuntimeError("Unexpected retry exhaustion calling Pancake API")


def get_all_pages(base_url: str, user_access_token: str) -> list[dict]:
    """Fetch all pages (activated + inactivated) with the master access token."""
    response = get_with_retry(
        url=f"{base_url}/v1/pages",
        params={"access_token": user_access_token},
    )
    data = response.json()

    # Pancake returns error_code 102 for invalid tokens (HTTP 200 with success=False)
    if not data.get("success", True) and data.get("error_code") == 102:
        raise RuntimeError("Pancake API error 102: invalid access_token")

    categorized = data.get("categorized", {})
    activated = categorized.get("activated") or []
    inactivated = categorized.get("inactivated") or []
    return list(activated) + list(inactivated)


def get_activated_pages(base_url: str, user_access_token: str) -> list[dict]:
    """Fetch only activated pages."""
    response = get_with_retry(
        url=f"{base_url}/v1/pages",
        params={"access_token": user_access_token},
    )
    data = response.json()
    if not data.get("success", True) and data.get("error_code") == 102:
        raise RuntimeError("Pancake API error 102: invalid access_token")

    categorized = data.get("categorized", {})
    return list(categorized.get("activated") or [])


def generate_page_access_token(base_url: str, page_id: str, user_access_token: str) -> str:
    """Exchange a user access token for a page-scoped access token."""
    for attempt in range(MAX_RETRIES + 1):
        response = requests.post(
            f"{base_url}/v1/pages/{page_id}/generate_page_access_token",
            params={"access_token": user_access_token},
            timeout=DEFAULT_TIMEOUT,
        )
        if response.status_code in (429, 500, 502, 503, 504):
            if attempt >= MAX_RETRIES:
                response.raise_for_status()
            wait = min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (2**attempt))
            logger.warning("PAT generation error %s. Retrying in %.1fs.", response.status_code, wait)
            time.sleep(wait)
            continue
        response.raise_for_status()
        break
    data = response.json()
    token = data.get("page_access_token") or data.get("access_token")
    if not token:
        raise RuntimeError(f"No token in Pancake response for page {page_id}: {data}")
    return token


__all__ = [
    "PAGE_SLEEP_SECONDS",
    "generate_page_access_token",
    "get_activated_pages",
    "get_all_pages",
    "get_with_retry",
]
