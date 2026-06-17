from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class SheetSpec:
    """Specification for a Google Sheets range to ingest.

    Each spec is self-contained: it carries its own ``spreadsheet_id`` so you
    can sync tabs from different spreadsheets in the same source.

    ``resource_name`` becomes the destination table name and the Dagster asset
    path segment. ``range_name`` is the Google Sheets range (a tab name, a named
    range, or an explicit range like ``Sheet1!A1:Z1000``).

    ``column_mapping`` maps original sheet header names to output column names.
    Use this when the sheet uses Vietnamese headers (e.g. ``{"Mã SP": "product_id"}``)
    and you need a stable name for ``primary_key`` or downstream references.
    ``primary_key`` references the **mapped** column name, not the original.
    Pass a string for a single-column key, or a list of strings for a composite key.

    ``write_disposition`` defaults to ``"merge"``. Set to ``"replace"`` when
    the sheet has no stable unique key.
    """

    resource_name: str
    range_name: str
    spreadsheet_id: str
    primary_key: Optional[str | list[str]] = None
    column_hints: dict[str, dict[str, str]] = field(default_factory=dict)
    column_mapping: dict[str, str] = field(default_factory=dict)
    write_disposition: str = "merge"


__all__ = ["SheetSpec"]