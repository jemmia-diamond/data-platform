from __future__ import annotations

import logging
import time
from typing import Optional

import requests

DEFAULT_TIMEOUT = 60
MAX_RETRIES = 5
BACKOFF_BASE_SECONDS = 1.0
BACKOFF_MAX_SECONDS = 60.0
PAGE_SLEEP_SECONDS = 1.0

logger = logging.getLogger(__name__)


class AdaptiveRateLimiter:
    """Runs at full speed; backs off automatically after 429 / 5xx, recovers after clean runs."""

    def __init__(self, max_delay: float = 60.0, backoff: float = 5.0, recovery: float = 0.05) -> None:
        """Initialise limiter.

        Args:
            max_delay: Upper bound on inter-request sleep in seconds.
            backoff: Multiplier applied to delay on each rate-limit hit.
            recovery: Seconds subtracted from delay after each clean response.
        """
        self._delay = 0.0
        self._max = max_delay
        self._backoff = backoff
        self._recovery = recovery

    def wait(self) -> None:
        """Sleep for the current adaptive delay before issuing the next request."""
        if self._delay > 0.0:
            time.sleep(self._delay)

    def on_success(self) -> None:
        """Decrease delay after a clean response."""
        self._delay = max(0.0, self._delay - self._recovery)

    def on_rate_limited(self) -> None:
        """Increase delay after a 429 or 5xx."""
        self._delay = min(self._max, max(0.5, self._delay * self._backoff))




def get_with_retry(
    url: str,
    params: Optional[dict] = None,
    rate_limiter: Optional[AdaptiveRateLimiter] = None,
) -> requests.Response:
    """GET with exponential backoff on 429 / 5xx / network errors. Raises after MAX_RETRIES, failing the job.

    Args:
        url: Target URL.
        params: Query parameters.
        rate_limiter: Optional adaptive limiter; updated on 429/5xx and clean responses.

    Returns:
        Successful HTTP response.

    Raises:
        requests.HTTPError: On non-retryable HTTP errors or exhausted retries.
        RuntimeError: If retry loop exits without returning (should not happen).
    """
    for attempt in range(MAX_RETRIES + 1):
        response = requests.get(url, params=params, timeout=DEFAULT_TIMEOUT)

        if response.status_code == 429:
            if attempt >= MAX_RETRIES:
                logger.error("Rate limit after %s retries - failing job.", MAX_RETRIES)
                response.raise_for_status()
            if rate_limiter:
                rate_limiter.on_rate_limited()
            retry_after_raw = response.headers.get("Retry-After")
            try:
                wait = float(retry_after_raw) if retry_after_raw else None
            except ValueError:
                wait = None
            wait = wait or min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (5**attempt))
            logger.warning("Rate limit hit. Retrying in %.1fs (%s/%s).", wait, attempt + 1, MAX_RETRIES + 1)
            time.sleep(wait)
            continue

        if response.status_code >= 500:
            if attempt >= MAX_RETRIES:
                logger.error("Server error %s after %s retries - failing job.", response.status_code, MAX_RETRIES)
                response.raise_for_status()
            if rate_limiter:
                rate_limiter.on_rate_limited()
            wait = min(BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (5**attempt))
            logger.warning("Server error %s. Retrying in %.1fs (%s/%s).", response.status_code, wait, attempt + 1, MAX_RETRIES + 1)
            time.sleep(wait)
            continue

        if not response.ok:
            logger.error("HTTP %s from Pancake API - failing job. URL: %s", response.status_code, response.url)
            response.raise_for_status()

        if rate_limiter:
            rate_limiter.on_success()
        return response

    raise RuntimeError("Unexpected retry exhaustion calling Pancake API")


__all__ = ["AdaptiveRateLimiter", "PAGE_SLEEP_SECONDS", "get_with_retry"]
