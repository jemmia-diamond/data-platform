from __future__ import annotations

from ingestion.misa.client import MisaClient
from ingestion.misa.resources.dictionary import build_dictionary_resource
from dlt.extract.resource import DltResource

DATA_TYPE = 2
PRIMARY_KEY = "inventory_item_id"


def build_inventory_items_resource(client: MisaClient, take: int = 100) -> DltResource:
    """MISA inventory items (vật tư/hàng hóa) - get_dictionary data_type=2.

    Note: get_dictionary PULL data_type values differ from the PUSH
    dictionary_type values used when saving (fn uses PUSH type 3 for the same
    entity). Verified by probing: GET type 2 = inventory_item, type 3 = stock.
    """
    return build_dictionary_resource(
        client,
        name="inventory_items",
        data_type=DATA_TYPE,
        primary_key=PRIMARY_KEY,
        take=take,
    )


__all__ = ["build_inventory_items_resource"]
