from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

import dlt
from dlt.common import logger
from dlt.extract.resource import DltResource
from dlt.sources.credentials import (
    GcpServiceAccountCredentials,
)

from ingestion.google_sheets.helpers import api_calls
from dlt.common.configuration.resolve import resolve_configuration
from ingestion.google_sheets.helpers.sheet_spec import SheetSpec
from ingestion.google_sheets.helpers.data_processing import (
    get_data_types,
    get_range_headers,
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

def build_hr_sheet_resource(
    spec: SheetSpec,
    spreadsheet_id: str,
    max_api_retries: int,
    sync_timestamp: str,
) -> DltResource:
    """Build a single eager, named DltResource for one HR sheet range.

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


DEFAULT_HR_SHEET_SPECS: tuple[SheetSpec, ...] = (
    SheetSpec(
        resource_name="recruitment",
        range_name="Tuyển Dụng",
        spreadsheet_id="1pZULTKpYkxRAn070KAgML5I1ZDAkXwxHqdMo5iSwtiQ",
        write_disposition="replace",
        column_mapping={
            "Ngày nhận yêu cầu":      "request_date",
            "Đợt TD Quý":             "quarter",
            "Đợt TD Tháng":           "month",
            "Phòng ban":              "department",
            "Vị trí tuyển dụng":      "position",
            "Họ và tên":              "candidate_name",
            "Ngày nhận hồ sơ":        "application_date",
            "Kết quả CV":             "cv_result",
            "Tình trạng ứng viên":    "candidate_status",
            "Ngày PV 1":              "interview_1_date",
            "Xác nhận tham gia PV 1": "interview_1_confirmed",
            "Kết quả PV 1":           "interview_1_result",
            "Ngày PV 2":              "interview_2_date",
            "Xác nhận tham gia PV 2": "interview_2_confirmed",
            "Kết quả PV 2":           "interview_2_result",
            "Kết quả final":          "final_result",
            "Ngày chấp nhận offer":   "offer_date",
            "Ngày nhận việc":         "start_date",
            "Tình trạng nhận việc":   "onboarding_status",
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

__all__ = [
    "DEFAULT_HR_SHEET_SPECS",
    "build_hr_sheet_resource",
    "_resolve_service_credentials"
]