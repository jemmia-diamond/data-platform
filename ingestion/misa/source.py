from __future__ import annotations

from typing import Optional

import dlt

from ingestion.misa.client import MisaClient
from ingestion.misa.resources import (
    build_account_objects_resource,
    build_banks_resource,
    build_inventory_items_resource,
    build_organization_units_resource,
    build_warehouse_inventories_resource,
)

DEFAULT_MISA_BASE_URL = "https://actapp.misa.vn"


@dlt.source(name="misa")
def misa_source(
    app_id: str = dlt.secrets.value,
    access_code: str = dlt.secrets.value,
    org_company_code: str = dlt.secrets.value,
    base_url: str = dlt.config.value,
):
    """Build the MISA source and let dlt resolve config from env vars.

    Credentials resolve from ``SOURCES__MISA__*`` (``app_id``/``access_code``/
    ``org_company_code`` as secrets, ``base_url`` as config). The same ACT Open
    API credentials the ``fn`` worker uses are reused here.
    """
    client = MisaClient(
        base_url=base_url,
        app_id=app_id,
        access_code=access_code,
        org_company_code=org_company_code,
    )

    inventory_items = build_inventory_items_resource(client)
    account_objects = build_account_objects_resource(client)
    organization_units = build_organization_units_resource(client)
    banks = build_banks_resource(client)
    warehouse_inventories = build_warehouse_inventories_resource(client)

    return inventory_items, account_objects, organization_units, banks, warehouse_inventories


def build_misa_source(
    *,
    base_url: Optional[str] = None,
    app_id: Optional[str] = None,
    access_code: Optional[str] = None,
    org_company_code: Optional[str] = None,
):
    """Helper for creating a MISA source with optional explicit overrides."""
    source_kwargs: dict = {}
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if app_id is not None:
        source_kwargs["app_id"] = app_id
    if access_code is not None:
        source_kwargs["access_code"] = access_code
    if org_company_code is not None:
        source_kwargs["org_company_code"] = org_company_code
    return misa_source(**source_kwargs)


__all__ = ["DEFAULT_MISA_BASE_URL", "build_misa_source", "misa_source"]
