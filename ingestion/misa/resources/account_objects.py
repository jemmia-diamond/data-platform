from __future__ import annotations

from ingestion.misa.client import MisaClient
from ingestion.misa.resources.dictionary import build_dictionary_resource
from dlt.extract.resource import DltResource

DATA_TYPE = 1
PRIMARY_KEY = "account_object_id"


def build_account_objects_resource(client: MisaClient, take: int = 100) -> DltResource:
    """MISA account objects (khách/nhà cung cấp/nhân viên) - get_dictionary data_type=1."""
    return build_dictionary_resource(
        client,
        name="account_objects",
        data_type=DATA_TYPE,
        primary_key=PRIMARY_KEY,
        take=take,
    )


__all__ = ["build_account_objects_resource"]
