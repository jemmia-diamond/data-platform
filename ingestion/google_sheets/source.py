from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional

import dlt
from .helpers.sheet_spec import SheetSpec

from dlt.extract.resource import DltResource

from .helpers import api_calls
from .helpers.data_processing import (
    get_spreadsheet_id,
)

from .resources import (
    DEFAULT_HR_SHEET_SPECS,
    build_hr_sheet_resource
)

@dlt.source(name="hr_google_sheets")
def hr_google_sheets_source(
    specs: tuple[SheetSpec, ...] = DEFAULT_HR_SHEET_SPECS,
    max_api_retries: int = 5,
) -> tuple[DltResource, ...]:
    """Build the Google Sheets source as a tuple of eager, named resources.

    Each spec carries its own ``spreadsheet_id``, so tabs from different
    spreadsheets can be synced in the same source.
    """
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    return tuple(
        build_hr_sheet_resource(
            spec,
            get_spreadsheet_id(spec.spreadsheet_id),
            max_api_retries,
            sync_timestamp
        )
        for spec in specs
    )


def build_google_sheets_source(
    specs: Optional[tuple[SheetSpec, ...]] = None,
    max_api_retries: int = 5,
):
    """Helper for creating a Google Sheets source."""
    return hr_google_sheets_source(
        specs=specs if specs is not None else DEFAULT_HR_SHEET_SPECS,
        max_api_retries=max_api_retries,
    )


__all__ = [
    "build_google_sheets_source"
]