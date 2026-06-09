from __future__ import annotations

from datetime import datetime, timezone
import logging
import time
from time import monotonic
from typing import Iterable, Optional

import dlt
import requests
from dlt.extract.resource import DltResource

DEFAULT_REQUEST_TIMEOUT = 30
DEFAULT_LIMIT = 250
MAX_LOCATION_IDS = 5
MAX_VARIANT_IDS = 20
MAX_COMBINATION = 200
MAX_429_RETRIES = 8
BACKOFF_BASE_SECONDS = 1.0
BACKOFF_MAX_SECONDS = 30.0
REQUEST_SPACING_SECONDS = 0.1
MAX_ELAPSED_SECONDS = 180.0

logger = logging.getLogger(__name__)


class InventoryBatchValidationError(Exception):
    """Raised when Haravan rejects a batch request with 422."""


def _parse_retry_after_seconds(value: Optional[str]) -> Optional[float]:
    if not value:
        return None
    try:
        seconds = float(value)
    except ValueError:
        return None
    if seconds <= 0:
        return None
    return seconds


def _get_json_with_retry(
    *,
    url: str,
    headers: dict[str, str],
    params: dict[str, str | int],
    allow_422: bool = False,
) -> dict:
    for attempt in range(MAX_429_RETRIES + 1):
        response = requests.get(
            url,
            headers=headers,
            params=params,
            timeout=DEFAULT_REQUEST_TIMEOUT,
        )

        if response.status_code == 429:
            if attempt >= MAX_429_RETRIES:
                response.raise_for_status()
            retry_after = _parse_retry_after_seconds(response.headers.get("Retry-After"))
            wait_seconds = retry_after or min(
                BACKOFF_MAX_SECONDS, BACKOFF_BASE_SECONDS * (2**attempt)
            )
            logger.warning(
                "Haravan rate limit at %s. Retry in %.1fs (%s/%s).",
                url,
                wait_seconds,
                attempt + 1,
                MAX_429_RETRIES + 1,
            )
            time.sleep(wait_seconds)
            continue

        if allow_422 and response.status_code == 422:
            raise InventoryBatchValidationError(response.text)

        response.raise_for_status()
        if REQUEST_SPACING_SECONDS > 0:
            time.sleep(REQUEST_SPACING_SECONDS)
        return response.json()

    raise RuntimeError("Unexpected retry exhaustion when calling Haravan API")


def _chunked(items: list[str], chunk_size: int) -> Iterable[list[str]]:
    for index in range(0, len(items), chunk_size):
        yield items[index : index + chunk_size]


def _fetch_location_ids(*, base_url: str, headers: dict[str, str]) -> Iterable[str]:
    page = 1
    loop_start = monotonic()

    while True:
        if monotonic() - loop_start > MAX_ELAPSED_SECONDS:
            logger.warning("_fetch_location_ids: exceeded max elapsed time (%.0fs). Stopping.", MAX_ELAPSED_SECONDS)
            break

        response_json = _get_json_with_retry(
            url=f"{base_url}locations.json",
            headers=headers,
            params={"limit": 50, "page": page},
        )
        locations = response_json.get("locations", [])
        if not locations:
            break

        for location in locations:
            location_id = location.get("id")
            if location_id is not None:
                yield str(location_id)

        if len(locations) < 50:
            break

        page += 1


def _fetch_changed_variant_ids_generator(
    *,
    base_url: str,
    headers: dict[str, str],
    updated_at_min: str,
    end_date: Optional[str],
) -> Iterable[tuple[list[str], str]]:
    seen_variant_ids: set[str] = set()
    page = 1
    max_seen_updated_at = updated_at_min
    max_seen_dt = _parse_haravan_datetime(updated_at_min)
    loop_start = monotonic()

    while True:
        if monotonic() - loop_start > MAX_ELAPSED_SECONDS:
            logger.warning("_fetch_changed_variant_ids: exceeded max elapsed time (%.0fs). Stopping.", MAX_ELAPSED_SECONDS)
            break

        params = {
            "limit": 50,
            "page": page,
            "order": "updated_at",
            "updated_at_min": updated_at_min,
        }
        if end_date:
            params["updated_at_max"] = end_date

        response_json = _get_json_with_retry(
            url=f"{base_url}products.json",
            headers=headers,
            params=params,
        )
        products = response_json.get("products", [])
        if not products:
            break

        batch_variant_ids = []
        for product in products:
            product_updated_at = product.get("updated_at")
            if isinstance(product_updated_at, str):
                product_dt = _parse_haravan_datetime(product_updated_at)
                if product_dt is not None:
                    if max_seen_dt is None or product_dt > max_seen_dt:
                        max_seen_dt = product_dt
                        max_seen_updated_at = product_updated_at

            for variant in product.get("variants", []):
                variant_id = variant.get("id")
                if variant_id is None:
                    continue
                variant_id_str = str(variant_id)
                if variant_id_str in seen_variant_ids:
                    continue
                seen_variant_ids.add(variant_id_str)
                batch_variant_ids.append(variant_id_str)

        if batch_variant_ids:
            yield batch_variant_ids, max_seen_updated_at

        if len(products) < 50:
            break
        page += 1


def _iter_inventory_locations(
    *,
    base_url: str,
    headers: dict[str, str],
    location_ids: list[str],
    variant_ids: list[str],
) -> Iterable[dict]:
    def _fetch_inventory_page(
        *,
        location_batch: list[str],
        variant_batch: list[str],
        since_id: Optional[str],
    ) -> list[dict]:
        params = {
            "location_ids": ",".join(location_batch),
            "variant_ids": ",".join(variant_batch),
            "limit": DEFAULT_LIMIT,
        }
        if since_id:
            params["since_id"] = since_id

        response_json = _get_json_with_retry(
            url=f"{base_url}inventory_locations.json",
            headers=headers,
            params=params,
            allow_422=True,
        )
        return response_json.get("inventory_locations", [])

    def _iter_with_split(location_batch: list[str], variant_batch: list[str], depth: int = 0) -> Iterable[dict]:
        # Add depth to prevent infinite recursion
        if depth >= 5:
            logger.error(
                "Recursion depth exceeded (>=5) for loc_id=%s variant_id=%s. Aborting this split batch to prevent infinite loop.",
                location_batch,
                variant_batch,
            )
            return

        since_id: str | None = None
        loop_start = monotonic()

        while True:
            if monotonic() - loop_start > MAX_ELAPSED_SECONDS:
                logger.warning("_iter_inventory_locations: exceeded max elapsed time (%.0fs). Stopping batch.", MAX_ELAPSED_SECONDS)
                return

            try:
                inventory_locations_data = _fetch_inventory_page(
                    location_batch=location_batch,
                    variant_batch=variant_batch,
                    since_id=since_id,
                )
            except InventoryBatchValidationError as error:
                if len(variant_batch) > 1:
                    midpoint = len(variant_batch) // 2
                    yield from _iter_with_split(location_batch, variant_batch[:midpoint], depth + 1)
                    yield from _iter_with_split(location_batch, variant_batch[midpoint:], depth + 1)
                    return
                if len(location_batch) > 1:
                    midpoint = len(location_batch) // 2
                    yield from _iter_with_split(location_batch[:midpoint], variant_batch, depth + 1)
                    yield from _iter_with_split(location_batch[midpoint:], variant_batch, depth + 1)
                    return
                logger.warning(
                    "Skip invalid inventory query for loc_id=%s variant_id=%s: %s",
                    location_batch[0] if location_batch else None,
                    variant_batch[0] if variant_batch else None,
                    error,
                )
                return

            if not inventory_locations_data:
                return

            for inventory_location in inventory_locations_data:
                yield inventory_location

            if len(inventory_locations_data) < DEFAULT_LIMIT:
                return

            last_id = inventory_locations_data[-1].get("id")
            if last_id is None:
                return

            next_since_id = str(last_id)
            if next_since_id == since_id:
                return
            since_id = next_since_id

    for location_batch in _chunked(location_ids, MAX_LOCATION_IDS):
        max_variant_batch = max(1, min(MAX_VARIANT_IDS, MAX_COMBINATION // len(location_batch)))
        for variant_batch in _chunked(variant_ids, max_variant_batch):
            yield from _iter_with_split(location_batch, variant_batch, 0)


def _apply_inventory_hints(resource: DltResource) -> DltResource:
    resource.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    resource.max_table_nesting = 0
    return resource


def _parse_haravan_datetime(value: str) -> Optional[datetime]:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def build_inventory_locations_resource(
    *,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
):
    """Build inventory_locations as an independent incremental resource."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json",
    }
    location_ids_cache: list[str] = []

    @dlt.resource(
        name="inventory_locations",
        primary_key=["loc_id", "variant_id"],
        write_disposition="merge",
    )
    def inventory_locations():
        nonlocal location_ids_cache
        if not location_ids_cache:
            # Materialize to list because we need to iterate over locations repeatedly
            location_ids_cache = list(_fetch_location_ids(base_url=base_url, headers=headers))
        if not location_ids_cache:
            return

        state = dlt.current.resource_state()
        products_updated_at_min = state.get("products_updated_at_min", start_date)

        # Run stream generator in batches instead of loading the entire large list into memory
        for variant_batch, max_seen_updated_at in _fetch_changed_variant_ids_generator(
            base_url=base_url,
            headers=headers,
            updated_at_min=products_updated_at_min,
            end_date=end_date,
        ):
            for inventory_location in _iter_inventory_locations(
                base_url=base_url,
                headers=headers,
                location_ids=location_ids_cache,
                variant_ids=variant_batch,
            ):
                inventory_location["_db_updated_at"] = sync_timestamp
                yield inventory_location

            # Save state after each batch instead of at the end of the function.
            # DLT will record this state along with the data pushed to the pipeline.
            if end_date is None:
                state["products_updated_at_min"] = max_seen_updated_at

    return _apply_inventory_hints(inventory_locations)


__all__ = ["build_inventory_locations_resource"]
