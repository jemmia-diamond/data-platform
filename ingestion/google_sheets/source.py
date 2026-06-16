from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

import dlt
from dlt.common.configuration.resolve import resolve_configuration
from dlt.common import logger
from dlt.extract.resource import DltResource
from dlt.sources.credentials import (
    GcpServiceAccountCredentials,
)

from .helpers import api_calls
from .helpers.data_processing import (
    get_data_types,
    get_range_headers,
    get_spreadsheet_id,
    process_range,
)


def _resolve_service_credentials() -> GcpServiceAccountCredentials:
    """Resolve GCP service account credentials, fixing private_key newlines.

    dlt's ``resolve_configuration`` reads ``private_key`` from env vars as-is,
    preserving literal ``\\n`` (backslash+n) characters. google-auth's
    ``load_pem_private_key`` expects actual newline characters. This helper
    patches the ``private_key`` field on the resolved credentials object so
    ``to_native_credentials()`` produces a valid PEM string.
    """
    credentials = resolve_configuration(
        GcpServiceAccountCredentials(),
        sections=("sources", "google_sheets", "credentials"),
    )
    if credentials.private_key and "\\n" in credentials.private_key:
        credentials.private_key = credentials.private_key.replace("\\n", "\n")
    return credentials


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


def _build_sheet_resource(
    spec: SheetSpec,
    spreadsheet_id: str,
    max_api_retries: int,
    sync_timestamp: str,
) -> DltResource:
    """Build a single eager, named DltResource for one sheet range.

    Credentials resolve lazily at extraction time (inside the resource body,
    not at decoration time), so constructing the source is safe without
    network access or credentials in the environment.
    """

    @dlt.resource(
        name=spec.resource_name,
        write_disposition=spec.write_disposition,
        primary_key=spec.primary_key,
    )
    def _sheet_range() -> Any:
        credentials = _resolve_service_credentials()
        service = api_calls.api_auth(credentials, max_api_retries=max_api_retries)

        loaded = api_calls.get_data_for_ranges(service, spreadsheet_id, [spec.range_name])
        if not loaded:
            logger.warning(f"Range {spec.range_name} returned no data. Skipping.")
            return
        _name, parsed_range, meta_range, values = loaded[0]
        if not values or len(values) < 2:
            logger.warning(
                f"Range {spec.range_name} has fewer than 2 rows (need header + data). Skipping."
            )
            return

        meta_values = api_calls.get_meta_for_ranges(service, spreadsheet_id, [str(meta_range)])
        sheet_group = next(
            (
                s
                for s in meta_values["sheets"]
                if s["properties"]["title"] == parsed_range.sheet_name
            ),
            None,
        )
        if not sheet_group or not sheet_group.get("data"):
            logger.warning(f"No cell metadata for range {spec.range_name}. Skipping.")
            return

        metadata = sheet_group["data"][0]
        headers_metadata = metadata["rowData"][0]["values"]
        headers = get_range_headers(headers_metadata, spec.range_name)
        if headers is None:
            headers = [f"col_{idx + 1}" for idx in range(len(headers_metadata))]
            data_row_metadata = headers_metadata
            rows_data = values
            logger.warning(
                f"Using automatic headers for {spec.range_name}; first row used as data."
            )
        else:
            data_row_metadata = metadata["rowData"][1]["values"]
            rows_data = values[1:]

        if spec.column_mapping:
            headers = [spec.column_mapping.get(h, h) for h in headers]

        data_types = get_data_types(data_row_metadata)
        yield from process_range(rows_data, headers=headers, data_types=data_types)

    resource = _sheet_range
    if spec.column_hints:
        resource.apply_hints(columns=spec.column_hints)
    resource.max_table_nesting = 0
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    return resource


DEFAULT_SHEET_SPECS: tuple[SheetSpec, ...] = (
    SheetSpec(
        resource_name="recruitment",
        range_name="Tuyển Dụng",
        spreadsheet_id="1pZULTKpYkxRAn070KAgML5I1ZDAkXwxHqdMo5iSwtiQ",
        write_disposition="replace",
        column_mapping={
            "Ngày nhận yêu cầu":     "request_date",
            "Đợt TD Quý":            "quarter",
            "Đợt TD Tháng":          "month",
            "Phòng ban":             "department",
            "Vị trí tuyển dụng":     "position",
            "Họ và tên":             "candidate_name",
            "Ngày nhận hồ sơ":       "application_date",
            "Kết quả CV":            "cv_result",
            "Tình trạng ứng viên":   "candidate_status",
            "Ngày PV 1":             "interview_1_date",
            "Xác nhận tham gia PV 1": "interview_1_confirmed",
            "Kết quả PV 1":          "interview_1_result",
            "Ngày PV 2":             "interview_2_date",
            "Xác nhận tham gia PV 2": "interview_2_confirmed",
            "Kết quả PV 2":          "interview_2_result",
            "Kết quả final":         "final_result",
            "Ngày chấp nhận offer":  "offer_date",
            "Ngày nhận việc":        "start_date",
            "Tình trạng nhận việc":  "onboarding_status",
        },
    ),
    SheetSpec(
        resource_name="employee_status",
        range_name="TTNV",
        spreadsheet_id="1pZULTKpYkxRAn070KAgML5I1ZDAkXwxHqdMo5iSwtiQ",
        write_disposition="merge",
        primary_key=["employee_name", "date"],
        column_mapping={
            "Tháng":                 "month",
            "Ngày":                  "date",
            "HỌ & TÊN":              "employee_name",
            "CẤP BẬC":               "rank",
            "CHỨC VỤ":               "job_title",
            "HÌNH THỨC":             "employment_type",
            "TEAM ":                 "team",
            "PHÒNG BAN":             "department",
            "KHỐI":                  "division",
            "KHU VỰC":               "region",
            "Ngày sinh ":            "birth_date",
            "Tháng sinh":            "birth_month",
            "Độ tuổi ":              "age",
            "Nhóm độ tuổi":          "age_group",
            "Tình trạng hôn nhân ":  "marital_status",
            "GIỚI TÍNH":             "gender",
            "Ngày vào":              "join_date",
            "Thâm niên":             "tenure",
            "NHÓM THÂM NIÊN ":       "tenure_group",
            "Trạng thái":            "status",
            "TRÌNH ĐỘ":              "education_level",
            "Ngày nghỉ việc":        "resignation_date",
            "Lý do":                 "resignation_reason",
        },
    ),
)


@dlt.source(name="google_sheets")
def google_sheets_source(
    specs: tuple[SheetSpec, ...] = DEFAULT_SHEET_SPECS,
    max_api_retries: int = 5,
) -> tuple[DltResource, ...]:
    """Build the Google Sheets source as a tuple of eager, named resources.

    Each spec carries its own ``spreadsheet_id``, so tabs from different
    spreadsheets can be synced in the same source.
    """
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    return tuple(
        _build_sheet_resource(
            spec, get_spreadsheet_id(spec.spreadsheet_id), max_api_retries, sync_timestamp
        )
        for spec in specs
    )


def build_google_sheets_source(
    specs: Optional[tuple[SheetSpec, ...]] = None,
    max_api_retries: int = 5,
):
    """Helper for creating a Google Sheets source."""
    return google_sheets_source(
        specs=specs if specs is not None else DEFAULT_SHEET_SPECS,
        max_api_retries=max_api_retries,
    )


__all__ = [
    "DEFAULT_SHEET_SPECS",
    "SheetSpec",
    "build_google_sheets_source",
    "google_sheets_source",
]