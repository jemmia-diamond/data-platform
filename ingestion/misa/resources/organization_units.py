from __future__ import annotations

from ingestion.misa.client import MisaClient
from ingestion.misa.resources.dictionary import build_dictionary_resource
from dlt.extract.resource import DltResource

DATA_TYPE = 6
PRIMARY_KEY = "organization_unit_id"


def build_organization_units_resource(client: MisaClient, take: int = 100) -> DltResource:
    """MISA organization units (đơn vị tổ chức) - get_dictionary data_type=6.

    fn pulls this at voucher-creation time (buildOrgUnitMap) to resolve
    unit_id/unit_name from unit_code for accounting voucher mapping.
    """
    return build_dictionary_resource(
        client,
        name="organization_units",
        data_type=DATA_TYPE,
        primary_key=PRIMARY_KEY,
        take=take,
    )


__all__ = ["build_organization_units_resource"]
