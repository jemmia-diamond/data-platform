from __future__ import annotations

from ingestion.misa.client import MisaClient
from ingestion.misa.resources.dictionary import build_dictionary_resource
from dlt.extract.resource import DltResource


def build_warehouse_inventories_resource(client: MisaClient, take: int = 100) -> DltResource:
    """MISA inventory balance (tồn kho theo kho) - get_list_inventory_balance.

    Point-in-time snapshot of stock-on-hand per item × warehouse. Always does a
    full load (no cursor) because the API ignores ``last_sync_time`` for balance
    data. Merge on composite PK ``[inventory_item_id, stock_id]`` deduplicates.
    """
    return build_dictionary_resource(
        client,
        name="warehouse_inventories",
        primary_key=["inventory_item_id", "stock_id"],
        fetch_fn=lambda skip, tk, lst: client.get_list_inventory_balance(
            skip=skip, take=tk, last_sync_time=lst,
        ),
        use_cursor=False,
        take=take,
    )


__all__ = ["build_warehouse_inventories_resource"]
