from __future__ import annotations

import base64
import json
from datetime import datetime, timezone
from typing import Any, Iterable, Optional
from urllib.parse import quote

import requests

DEFAULT_TIMEOUT_SECONDS = 60


def normalize_frappe_datetime(value: Optional[str]) -> Optional[str]:
    """Normalize datetime strings for Frappe filters.

    Frappe commonly expects "YYYY-MM-DD HH:MM:SS" (optionally with micros).
    We accept ISO8601 (with optional Z) and convert to UTC.
    """

    if value is None:
        return None
    value = value.strip()
    if not value:
        return None

    # Already in a Frappe-friendly format.
    if "T" not in value and value.count(":") >= 1:
        return value
    # Also allow pure dates.
    if "T" not in value and len(value) == 10:
        return value

    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        # Best effort: return the original string if we can't parse it.
        return value

    return dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _extract_payload(payload: Any) -> Any:
    if not isinstance(payload, dict):
        return payload
    if payload.get("exc"):
        raise RuntimeError(f"Frappe exception: {payload.get('exc')}")
    if payload.get("exception"):
        raise RuntimeError(f"Frappe exception: {payload.get('exception')}")
    if "message" in payload and payload["message"] is not None:
        return payload["message"]
    if "data" in payload and payload["data"] is not None:
        return payload["data"]
    return payload


def _build_auth_header(*, api_key: str, api_secret: str, api_auth_scheme: str) -> dict[str, str]:
    if api_auth_scheme == "basic":
        token = base64.b64encode(f"{api_key}:{api_secret}".encode("utf-8")).decode("ascii")
        return {"Authorization": f"Basic {token}"}

    # Frappe API keys typically use: Authorization: token <api_key>:<api_secret>
    return {"Authorization": f"token {api_key}:{api_secret}"}


class FrappeClient:
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        api_secret: str,
        api_auth_scheme: str = "token",
        timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
        verify: bool = True,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.verify = verify

        self.session = requests.Session()
        self.session.headers.update({"Accept": "application/json"})
        self.session.headers.update(
            _build_auth_header(api_key=api_key, api_secret=api_secret, api_auth_scheme=api_auth_scheme)
        )

    def _get(self, *, path: str, params: Optional[dict[str, Any]] = None) -> Any:
        url = self.base_url + path
        response = self.session.get(url, params=params, timeout=self.timeout_seconds, verify=self.verify)
        response.raise_for_status()
        return _extract_payload(response.json())

    def get_doc(self, *, doctype: str, name: str) -> Any:
        return self._get(path=f"/api/resource/{quote(doctype)}/{quote(name)}")

    def iter_list(
        self,
        *,
        doctype: str,
        fields: list[str],
        filters: Optional[list[list[Any]]] = None,
        order_by: Optional[str] = None,
        page_size: int = 200,
    ) -> Iterable[dict[str, Any]]:
        limit_start = 0
        path = f"/api/resource/{quote(doctype)}"

        while True:
            params: dict[str, Any] = {
                "fields": json.dumps(fields),
                "limit_start": limit_start,
                "limit_page_length": page_size,
            }
            if filters:
                params["filters"] = json.dumps(filters)
            if order_by:
                params["order_by"] = order_by

            data = self._get(path=path, params=params)
            rows = data or []
            if not rows:
                return

            for row in rows:
                if isinstance(row, dict):
                    yield row

            if len(rows) < page_size:
                return
            limit_start += page_size


__all__ = ["DEFAULT_TIMEOUT_SECONDS", "FrappeClient", "normalize_frappe_datetime"]

