from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Helper to construct Dagster asset paths for NocoDB."""
    return tuple(("ingestion", "nocodb", resource_name) for resource_name in resource_names)


NOCODB_EXECUTION_UNITS = validate_execution_units(
    (
        # ── Hourly groups ──────────────────────────────────────────────
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="diamond",
            name_segments=("nocodb",),
            asset_paths=_asset_paths(
                "diamonds",
                "diamond_price_list",
                "moissanite",
                "diamonds_history",
                "diamonds_history_diamonds",
            ),
            description="Sync diamond inventory and history: diamonds, diamond_price_list, moissanite, diamonds_history, diamonds_history_diamonds",
            cadence="hourly",
            cron_schedule="02 * * * *",
            schedule_token="every_1h",
            schedule_description="Run Diamond Resources sync every hour at :02",
            max_runtime_seconds=2700,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="product_catalog",
            name_segments=("nocodb",),
            asset_paths=_asset_paths("products", "variants"),
            description="Sync product catalog: products, variants",
            cadence="hourly",
            cron_schedule="22 * * * *",
            schedule_token="every_1h",
            schedule_description="Run Product Catalog sync every hour at :22",
            max_runtime_seconds=2700,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="inventory",
            name_segments=("nocodb",),
            asset_paths=_asset_paths(
                "variant_serials",
                "variant_serials_diamonds",
                "jewelries",
                "temporary_products",
            ),
            description="Sync physical inventory: variant_serials, variant_serials_diamonds, jewelries, temporary_products",
            cadence="hourly",
            cron_schedule="42 * * * *",
            schedule_token="every_1h",
            schedule_description="Run Inventory sync every hour at :42",
            max_runtime_seconds=2700,
        ),
        # ── 2-hourly groups ────────────────────────────────────────────
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="design_core",
            name_segments=("nocodb",),
            asset_paths=_asset_paths("designs", "design_details", "design_design_images", "wedding_rings"),
            description="Sync R&D design data: designs, design_details, design_design_images, wedding_rings",
            cadence="2hourly",
            cron_schedule="12 */2 * * *",
            schedule_token="every_2h",
            schedule_description="Run Design Core sync every 2 hours at :12",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="marketing",
            name_segments=("nocodb",),
            asset_paths=_asset_paths(
                "collections",
                "haravan_collections",
                "products_haravan_collection",
                "diamonds_haravan_collection",
                "variants_haravan_collection",
            ),
            description="Sync marketing collections and junction tables",
            cadence="2hourly",
            cron_schedule="52 */2 * * *",
            schedule_token="every_2h",
            schedule_description="Run Marketing Collections sync every 2 hours at :52",
            max_runtime_seconds=3600,
        ),
    )
)

__all__ = ["NOCODB_EXECUTION_UNITS"]