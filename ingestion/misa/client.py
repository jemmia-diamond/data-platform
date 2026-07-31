from __future__ import annotations

import json
import logging
import time
from typing import Any, Optional

import requests

logger = logging.getLogger(__name__)

DEFAULT_TIMEOUT_SECONDS = 60

# 429 (rate-limit) retry tuning for get_dictionary.
MAX_RETRIES = 4
RETRY_BACKOFF_SECONDS = 2.0
MAX_RETRY_AFTER_SECONDS = 60.0

OAUTH_PATH = "/api/oauth/actopen/connect"
GET_DICTIONARY_PATH = "/apir/sync/actopen/get_dictionary"
GET_INVENTORY_BALANCE_PATH = "/apir/sync/actopen/get_list_inventory_balance"


class MisaClient:
    """Thin client for the MISA AMIS ACT Open API.

    Handles OAuth access-token retrieval and the ``get_dictionary`` master-data
    endpoint. Mirrors the behaviour of the ``MisaClient`` in the ``fn`` worker
    (``https://actapp.misa.vn``) so the same credentials can be reused.
    """

    def __init__(
        self,
        *,
        base_url: str,
        app_id: str,
        access_code: str,
        org_company_code: str,
        timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.app_id = app_id
        self.access_code = access_code
        self.org_company_code = org_company_code
        self.timeout_seconds = timeout_seconds

        self._access_token: Optional[str] = None

    def get_access_token(self) -> str:
        """Fetch and cache the MISA access token (TTL ~12h on MISA's side).

        The token is cached on the instance for the lifetime of a single
        ingestion run. Daily cadence makes cross-run caching unnecessary.
        """
        if self._access_token:
            return self._access_token

        url = self.base_url + OAUTH_PATH
        payload = {
            "app_id": self.app_id,
            "access_code": self.access_code,
            "org_company_code": self.org_company_code,
        }
        response = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()
        body = response.json()

        if not body.get("Success", False):
            raise RuntimeError(
                f"MISA OAuth failed: {body.get('ErrorCode')} {body.get('ErrorMessage')}"
            )

        data = body.get("Data")
        if isinstance(data, str):
            data = json.loads(data)
        token = data.get("access_token") if isinstance(data, dict) else None
        if not token:
            raise RuntimeError("MISA OAuth response did not contain an access_token")

        self._access_token = token
        logger.info("Acquired MISA access token.")
        return token

    def get_dictionary(
        self,
        data_type: int,
        skip: int = 0,
        take: int = 100,
        last_sync_time: Optional[str] = None,
    ) -> tuple[list[dict[str, Any]], Optional[str]]:
        """Fetch one page of a MISA master-data dictionary.

        Args:
            data_type: MISA GET dictionary type (1=account_object, 2=inventory_item,
                3=stock, 6=organization_unit, 8=bank). NOTE: these GET types differ
                from the PUSH ``dictionary_type`` values used when saving.
            skip: Number of records to skip (pagination offset).
            take: Page size (MISA documents a max of 100).
            last_sync_time: Incremental cursor from a previous page/run. ``None``
                performs a full load.

        Returns:
            A ``(rows, last_sync_time)`` tuple where ``rows`` is the list of
            records for this page and ``last_sync_time`` is the cursor to use on
            the next call (from the response ``CustomData.LastSyncTime``).

        Retries on HTTP 429 (rate limit) honouring ``Retry-After``.
        """
        payload = {
            "app_id": self.app_id,
            "data_type": data_type,
            "skip": skip,
            "take": take,
            "last_sync_time": last_sync_time,
        }
        return self._post_with_retry(GET_DICTIONARY_PATH, payload)

    def get_list_inventory_balance(
        self,
        skip: int = 0,
        take: int = 100,
        last_sync_time: Optional[str] = None,
    ) -> tuple[list[dict[str, Any]], Optional[str]]:
        """Fetch one page of MISA inventory balance (tồn kho theo kho).

        Endpoint ``get_list_inventory_balance`` returns current stock-on-hand per
        item × warehouse. This is a point-in-time snapshot, so ``last_sync_time``
        is typically ignored by MISA — callers should do a full load on each run.

        Returns:
            ``(rows, last_sync_time)`` — same shape as :meth:`get_dictionary`.
        """
        payload = {
            "app_id": self.app_id,
            "skip": skip,
            "take": take,
            "last_sync_time": last_sync_time,
        }
        return self._post_with_retry(GET_INVENTORY_BALANCE_PATH, payload)

    def _post_with_retry(
        self,
        path: str,
        payload: dict[str, Any],
    ) -> tuple[list[dict[str, Any]], Optional[str]]:
        """POST to a MISA sync endpoint with 429 retry and shared response parsing."""
        token = self.get_access_token()
        url = self.base_url + path
        headers = {
            "X-MISA-AccessToken": token,
            "Content-Type": "application/json",
        }

        backoff = RETRY_BACKOFF_SECONDS
        for attempt in range(MAX_RETRIES + 1):
            response = requests.post(
                url, json=payload, headers=headers, timeout=self.timeout_seconds
            )
            if response.status_code == 429:
                wait = min(_parse_retry_after(response.headers.get("Retry-After"), backoff), MAX_RETRY_AFTER_SECONDS)
                if attempt < MAX_RETRIES:
                    logger.warning(
                        "MISA %s 429 rate-limited; retry %d/%d after %.1fs",
                        path, attempt + 1, MAX_RETRIES, wait,
                    )
                    time.sleep(wait)
                    backoff *= 2
                    continue
                raise RuntimeError(f"MISA {path} rate-limited (429) after retries exhausted")

            response.raise_for_status()
            body = response.json()

            if not body.get("Success", False):
                raise RuntimeError(
                    f"MISA {path} failed: {body.get('ErrorCode')} {body.get('ErrorMessage')}"
                )

            rows = _parse_json_field(body.get("Data"))
            last_sync = _parse_last_sync_time(body.get("CustomData"))
            if not isinstance(rows, list):
                raise RuntimeError(f"MISA {path} returned an unexpected Data shape")
            return rows, last_sync

        raise RuntimeError(f"MISA {path} exhausted retries unexpectedly")


def _parse_json_field(value: Any) -> Any:
    if isinstance(value, str):
        return json.loads(value)
    return value


def _parse_retry_after(header_value: Optional[str], fallback: float) -> float:
    """Parse a ``Retry-After`` header into seconds, falling back to ``fallback``."""
    if not header_value:
        return fallback
    try:
        return max(0.0, float(header_value))
    except (TypeError, ValueError):
        return fallback


def _parse_last_sync_time(custom_data: Any) -> Optional[str]:
    parsed = _parse_json_field(custom_data)
    if isinstance(parsed, dict):
        last_sync_time = parsed.get("LastSyncTime")
        if isinstance(last_sync_time, str) and last_sync_time:
            return last_sync_time
    return None


__all__ = ["DEFAULT_TIMEOUT_SECONDS", "MisaClient"]
