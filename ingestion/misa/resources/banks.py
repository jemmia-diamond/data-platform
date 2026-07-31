from __future__ import annotations

from ingestion.misa.client import MisaClient
from ingestion.misa.resources.dictionary import build_dictionary_resource
from dlt.extract.resource import DltResource

DATA_TYPE = 8
PRIMARY_KEY = "bank_account_id"


def build_banks_resource(client: MisaClient, take: int = 100) -> DltResource:
    """MISA bank accounts (tài khoản ngân hàng) - get_dictionary data_type=8.

    fn pulls this at voucher-creation time to resolve bank_name /
    bank_branch_name from bank_account_number for payment voucher mapping.
    """
    return build_dictionary_resource(
        client,
        name="banks",
        data_type=DATA_TYPE,
        primary_key=PRIMARY_KEY,
        take=take,
    )


__all__ = ["build_banks_resource"]
