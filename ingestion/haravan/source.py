from __future__ import annotations

from typing import Optional

import dlt

from .resources import (
    build_orders_resource,
    build_customers_resource,
    build_products_resource,
    build_locations_resource,
    build_events_resource,
    build_users_resource,
    build_custom_collections_resource,
    build_smart_collections_resource,
    build_inventory_locations_resource,
)

DEFAULT_HARAVAN_BASE_URL = "https://apis.haravan.com/com/"
DEFAULT_START_DATE = "2026-04-01T00:00:00.000Z"


@dlt.source(name="haravan")
def haravan_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    api_token: str = dlt.secrets.value,
):
    """Build the Haravan source and let dlt resolve config from env vars."""
    orders_resource = build_orders_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    customers_resource = build_customers_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    products_resource = build_products_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    locations_resource = build_locations_resource(
        base_url=base_url,
        api_token=api_token,
    )
    events_resource = build_events_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    users_resource = build_users_resource(
        base_url=base_url,
        api_token=api_token,
    )
    custom_collections_resource = build_custom_collections_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    smart_collections_resource = build_smart_collections_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )
    inventory_locations_resource = build_inventory_locations_resource(
        base_url=base_url,
        api_token=api_token,
        start_date=start_date,
        end_date=end_date,
    )

    return (
        orders_resource,
        customers_resource,
        products_resource,
        locations_resource,
        inventory_locations_resource,
        events_resource,
        users_resource,
        custom_collections_resource,
        smart_collections_resource,
    )


def build_haravan_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    api_token: Optional[str] = None,
):
    """Helper for creating a Haravan source with optional explicit overrides."""
    source_kwargs = {
        "start_date": start_date,
        "end_date": end_date,
    }
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if api_token is not None:
        source_kwargs["api_token"] = api_token
    return haravan_source(**source_kwargs)


__all__ = [
    "DEFAULT_HARAVAN_BASE_URL",
    "DEFAULT_START_DATE",
    "build_haravan_source",
]
