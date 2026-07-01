from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

import yaml
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests
from dlt.sources.helpers.rest_client.paginators import JSONResponseCursorPaginator
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

DEFAULT_PAGE_SIZE = 500

_TENANT_TOKEN_ENDPOINT = "auth/v3/tenant_access_token/internal"
_WIKI_NODE_ENDPOINT = "wiki/v2/spaces/get_node"
_BITABLE_RECORDS_PATH = "tables/{table_id}/records"

_TABLE_SPECS_PATH = Path(__file__).with_name("tables.yml")


@dataclass(frozen=True)
class TableSpec:
    """Specification for a single Lark Bitable table to ingest.

    Mirrors the NocoDB ``TableSpec`` pattern: an explicit, type-safe declaration
    of one table, but populated from an external YAML catalog. Each table carries
    its own ``wiki_token`` so tables from different Wiki spaces / Bases can be
    ingested by the same source.
    """

    resource_name: str
    table_id: str
    wiki_token: str
    primary_key: str | list[str] = "record_id"
    column_hints: dict[str, dict[str, str]] = field(default_factory=dict)


def load_table_specs(config_path: Path = _TABLE_SPECS_PATH) -> tuple[TableSpec, ...]:
    """Load the Bitable table catalog from the external YAML file.

    Args:
        config_path: Path to the YAML file declaring the ``tables`` list.

    Returns:
        A tuple of ``TableSpec`` instances, one per declared table.
    """
    catalog = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    return tuple(TableSpec(**entry) for entry in catalog["tables"])


TABLE_SPECS: tuple[TableSpec, ...] = load_table_specs()


def get_tenant_access_token(base_url: str, app_id: str, app_secret: str) -> str:
    """Exchange Lark application credentials for a tenant access token.

    Args:
        base_url: Lark open-apis base URL (e.g. ``https://open.larksuite.com/open-apis``).
        app_id: Lark custom app identifier.
        app_secret: Lark custom app secret.

    Returns:
        A short-lived tenant access token used as the bearer credential.

    Raises:
        RuntimeError: If the Lark API responds with a non-zero status code.
    """
    response = requests.post(
        f"{base_url}/{_TENANT_TOKEN_ENDPOINT}",
        json={"app_id": app_id, "app_secret": app_secret},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != 0:
        raise RuntimeError(f"Lark tenant_access_token request failed: {payload}")
    return payload["tenant_access_token"]


def resolve_wiki_app_token(base_url: str, access_token: str, wiki_token: str) -> str:
    """Resolve the Bitable ``app_token`` embedded in a Lark Wiki node.

    Args:
        base_url: Lark open-apis base URL.
        access_token: Tenant access token used as the bearer credential.
        wiki_token: Token of the Wiki node that embeds the Base.

    Returns:
        The ``app_token`` of the Base embedded in the Wiki node.

    Raises:
        RuntimeError: If the Lark API responds with a non-zero status code.
    """
    response = requests.get(
        f"{base_url}/{_WIKI_NODE_ENDPOINT}",
        headers={"Authorization": f"Bearer {access_token}"},
        params={"token": wiki_token, "obj_type": "wiki"},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != 0:
        raise RuntimeError(f"Lark wiki get_node request failed: {payload}")
    return payload["data"]["node"]["obj_token"]


def build_table_resource(
    *,
    spec: TableSpec,
    base_url: str,
    access_token: str,
    app_token: str,
) -> DltResource:
    """Create a DltResource for a single Lark Bitable table.

    The resource merges on ``record_id`` for idempotent re-runs and paginates via
    the Lark ``page_token`` cursor using the dlt REST API helpers.

    Args:
        spec: Declarative specification of the table to ingest.
        base_url: Lark open-apis base URL.
        access_token: Tenant access token used as the bearer credential.
        app_token: Resolved Bitable application token owning the table.

    Returns:
        A configured dlt resource that yields Bitable records for the table.
    """
    sync_timestamp = datetime.now(timezone.utc).isoformat()

    resource_def: dict[str, Any] = {
        "name": spec.resource_name,
        "primary_key": spec.primary_key,
        "write_disposition": "merge",
        "endpoint": {
            "path": _BITABLE_RECORDS_PATH.format(table_id=spec.table_id),
            "params": {
                "page_size": DEFAULT_PAGE_SIZE,
                "automatic_fields": "true",
            },
            "data_selector": "data.items",
            "paginator": JSONResponseCursorPaginator(
                cursor_path="data.page_token",
                cursor_param="page_token",
            ),
        },
    }

    config: RESTAPIConfig = {
        "client": {
            "base_url": f"{base_url}/bitable/v1/apps/{app_token}/",
            "headers": {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
        },
        "resources": [resource_def],
    }

    resource = rest_api_resources(config)[0]
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    resource.max_table_nesting = 0
    return resource


__all__ = [
    "TableSpec",
    "TABLE_SPECS",
    "build_table_resource",
    "get_tenant_access_token",
    "load_table_specs",
    "resolve_wiki_app_token",
]
