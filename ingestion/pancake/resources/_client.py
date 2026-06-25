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
            logger.warning("Rate limit hit. Retrying in %.1fs (%s/%s).", wait, attempt + 1, MAX_RETRIES + 1)
            time.sleep(wait)
            continue

        if response.status_code >= 500:
            if attempt >= MAX_RETRIES:
                response.raise_for_status()
            wait = min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (2**attempt))
            logger.warning("Server error %s. Retrying in %.1fs.", response.status_code, wait)
            time.sleep(wait)
            continue

        response.raise_for_status()
        return response

    raise RuntimeError("Unexpected retry exhaustion calling Pancake API")


__all__ = ["PAGE_SLEEP_SECONDS", "get_with_retry"]
