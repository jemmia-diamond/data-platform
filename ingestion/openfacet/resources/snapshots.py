from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable

import dlt
import requests
from dlt.extract.resource import DltResource


@dataclass(frozen=True)
class EndpointSpec:
    """Specification for a single OpenFacet snapshot endpoint.

    Each OpenFacet endpoint returns one JSON document per fetch (no pagination).
    ``has_ts`` indicates whether the response carries a top-level ``ts`` field,
    which is used to derive ``snapshot_date``. ``ratio_models.json`` has no ``ts``
    and falls back to the fetch UTC date.
    """

    resource_name: str
    path: str
    has_ts: bool


DEFAULT_ENDPOINT_SPECS: tuple[EndpointSpec, ...] = (
    EndpointSpec(resource_name="dcx_index", path="index.json", has_ts=True),
    EndpointSpec(resource_name="price_matrix", path="matrix.json", has_ts=True),
    EndpointSpec(resource_name="ratio_models", path="ratio_models.json", has_ts=False),
    EndpointSpec(resource_name="market_depth", path="depth.json", has_ts=True),
)


def _fetch_json(
    base_url: str,
    path: str,
    *,
    timeout: float = 30.0,
    retries: int = 3,
) -> dict[str, Any]:
    """GET a single OpenFacet endpoint with linear backoff retry.

    OpenFacet is unauthenticated and serves tiny JSON documents, so a plain
    ``requests.get`` with a short retry loop is sufficient and matches the
    connector-style reliability goal (2 runs/day absorb transient failures).
    """
    url = f"{base_url.rstrip('/')}/{path.lstrip('/')}"
    last_exc: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            response = requests.get(url, timeout=timeout, headers={"Accept": "application/json"})
            response.raise_for_status()
            return response.json()
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
            if attempt == retries:
                break
            time.sleep(min(2.0 * attempt, 8.0))
    raise RuntimeError(
        f"Failed to fetch OpenFacet {url} after {retries} attempts: {last_exc}"
    )


def _resolve_snapshot(payload: dict[str, Any], fetch_dt: datetime, *, has_ts: bool) -> tuple[str, str | None]:
    """Return (snapshot_date ISO, snapshot_ts) from the API ``ts`` when present.

    Falls back to the fetch UTC date for endpoints without ``ts`` (ratio_models).
    """
    ts = payload.get("ts") if has_ts else None
    if isinstance(ts, str) and len(ts) >= 10:
        return ts[:10], ts
    return fetch_dt.date().isoformat(), ts


def _index_scalars(payload: dict[str, Any]) -> dict[str, Any]:
    market = payload.get("market") or {}
    dxy = market.get("dxy") or {}
    gold = market.get("gold") or {}
    return {
        "dcx": payload.get("dcx"),
        "trend": payload.get("trend"),
        "trend_7d": payload.get("trend_7d"),
        "trend_30d": payload.get("trend_30d"),
        "gold_price": gold.get("price"),
        "gold_unit": gold.get("unit"),
        "gold_date": gold.get("date"),
        "dxy_price": dxy.get("price"),
        "dxy_unit": dxy.get("unit"),
        "dxy_date": dxy.get("date"),
        "specs": payload.get("specs"),
        "market": market,
    }


def _matrix_scalars(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "clarity_grades": payload.get("c"),
        "color_grades": payload.get("r"),
        "shape": payload.get("s"),
        "log_matrix": payload.get("l"),
        "markers": payload.get("m"),
    }


def _ratio_scalars(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "version": payload.get("version"),
        "shapes": payload.get("shapes"),
    }


def _depth_scalars(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "depth_clarity": payload.get("clarity"),
        "depth_color": payload.get("color"),
        "depth_colclar": payload.get("colclar"),
    }


_EXTRACTORS: dict[str, Callable[[dict[str, Any]], dict[str, Any]]] = {
    "dcx_index": _index_scalars,
    "price_matrix": _matrix_scalars,
    "ratio_models": _ratio_scalars,
    "market_depth": _depth_scalars,
}

_BASE_COLUMN_HINTS: dict[str, dict[str, str]] = {
    "snapshot_date": {"data_type": "date", "nullable": False},
    "snapshot_ts": {"data_type": "timestamp"},
    "fetched_at": {"data_type": "timestamp", "nullable": False},
    "payload": {"data_type": "json"},
    "_db_updated_at": {"data_type": "timestamp", "nullable": False},
}

_COLUMN_HINTS_BY_RESOURCE: dict[str, dict[str, dict[str, str]]] = {
    "dcx_index": {
        **_BASE_COLUMN_HINTS,
        "dcx": {"data_type": "double"},
        "trend": {"data_type": "double"},
        "trend_7d": {"data_type": "double"},
        "trend_30d": {"data_type": "double"},
        "gold_price": {"data_type": "double"},
        "gold_unit": {"data_type": "text"},
        "gold_date": {"data_type": "text"},
        "dxy_price": {"data_type": "double"},
        "dxy_unit": {"data_type": "text"},
        "dxy_date": {"data_type": "text"},
        "specs": {"data_type": "json"},
        "market": {"data_type": "json"},
    },
    "price_matrix": {
        **_BASE_COLUMN_HINTS,
        "clarity_grades": {"data_type": "json"},
        "color_grades": {"data_type": "json"},
        "shape": {"data_type": "json"},
        "log_matrix": {"data_type": "json"},
        "markers": {"data_type": "json"},
    },
    "ratio_models": {
        **_BASE_COLUMN_HINTS,
        "version": {"data_type": "text"},
        "shapes": {"data_type": "json"},
    },
    "market_depth": {
        **_BASE_COLUMN_HINTS,
        "depth_clarity": {"data_type": "json"},
        "depth_color": {"data_type": "json"},
        "depth_colclar": {"data_type": "json"},
    },
}


def build_snapshot_resource(
    spec: EndpointSpec,
    base_url: str,
    sync_timestamp: str,
) -> DltResource:
    """Build a daily document-snapshot DltResource for one OpenFacet endpoint.

    Yields exactly one row per fetch keyed by ``snapshot_date`` with
    ``write_disposition="merge"``, so a same-day re-run updates (never
    duplicates) the existing day's row. The untouched API document is preserved
    verbatim in the ``payload`` JSONB column; convenience scalar/jsonb copies
    are added per endpoint.
    """

    @dlt.resource(
        name=spec.resource_name,
        write_disposition="merge",
        primary_key="snapshot_date",
    )
    def _snapshot() -> Any:
        payload = _fetch_json(base_url, spec.path)
        fetch_dt = datetime.now(timezone.utc)
        snapshot_date, snapshot_ts = _resolve_snapshot(payload, fetch_dt, has_ts=spec.has_ts)
        row: dict[str, Any] = {
            "snapshot_date": snapshot_date,
            "snapshot_ts": snapshot_ts,
            "fetched_at": fetch_dt.isoformat(),
            "payload": payload,
        }
        extractor = _EXTRACTORS.get(spec.resource_name)
        if extractor is not None:
            row.update(extractor(payload))
        yield row

    resource = _snapshot
    resource.max_table_nesting = 0
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(columns=_COLUMN_HINTS_BY_RESOURCE.get(spec.resource_name, _BASE_COLUMN_HINTS))
    return resource


__all__ = [
    "DEFAULT_ENDPOINT_SPECS",
    "EndpointSpec",
    "build_snapshot_resource",
]
