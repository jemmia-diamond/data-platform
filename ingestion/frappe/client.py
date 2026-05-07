from __future__ import annotations

import base64
import json
from datetime import datetime, timezone
from typing import Any, Optional

import requests

DEFAULT_TIMEOUT_SECONDS = 60
SYSTEM_CONSOLE_EXECUTE_CMD = "frappe.desk.doctype.system_console.system_console.execute_code"


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

    def _post(self, *, path: str = "", data: Optional[dict[str, Any]] = None) -> Any:
        url = self.base_url + path
        response = self.session.post(url, data=data, timeout=self.timeout_seconds, verify=self.verify)
        response.raise_for_status()
        return _extract_payload(response.json())

    def execute_sql(self, sql: str) -> list[dict[str, Any]]:
        """Execute SQL through the ERPNext System Console API."""
        payload = {
            "cmd": SYSTEM_CONSOLE_EXECUTE_CMD,
            "doc": json.dumps(
                {
                    "name": "System Console",
                    "docstatus": 0,
                    "type": "SQL",
                    "doctype": "System Console",
                    "console": sql,
                }
            ),
        }
        result = self._post(data=payload)

        output = result.get("output") if isinstance(result, dict) else result

        if output in (None, ""):
            return []
        if isinstance(output, list):
            return [row for row in output if isinstance(row, dict)]
        if isinstance(output, str):
            try:
                parsed = json.loads(output)
            except json.JSONDecodeError:
                # Return raw string if not JSON (e.g. error message)
                return []
            if isinstance(parsed, list):
                return [row for row in parsed if isinstance(row, dict)]
            raise RuntimeError("Unexpected SQL output shape from Frappe System Console")

        raise RuntimeError("Unexpected SQL output type from Frappe System Console")

    def get_json_object_expression(self, table_name: str) -> str:
        """Fetch columns for a table and build a JSON_OBJECT(...) expression."""
        if not hasattr(self, "_column_cache"):
            self._column_cache: dict[str, str] = {}

        if table_name in self._column_cache:
            return self._column_cache[table_name]

        # Query information_schema to get all columns of the child table
        # We use a raw execute_sql call here
        cols_raw = self.execute_sql(
            f"SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS "
            f"WHERE TABLE_NAME = '{table_name.replace('`', '')}' "
            f"AND TABLE_SCHEMA = DATABASE()"
        )
        if not cols_raw:
            # Fallback if we can't get columns
            return "`name`"

        # Build JSON_OBJECT('col1', `col1`, 'col2', `col2`, ...)
        pairs = [f"'{c['COLUMN_NAME']}', `{c['COLUMN_NAME']}`" for c in cols_raw]
        expr = f"JSON_OBJECT({', '.join(pairs)})"
        self._column_cache[table_name] = expr
        return expr


__all__ = ["DEFAULT_TIMEOUT_SECONDS", "FrappeClient", "normalize_frappe_datetime"]
