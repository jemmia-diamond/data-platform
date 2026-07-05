from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterator, NamedTuple, Optional, Union

import dlt
import yaml
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests
from dlt.sources.helpers.rest_client.paginators import JSONResponseCursorPaginator
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

from ingestion.common import RAW_UPDATED_AT_COLUMN, apply_raw_hints, sync_timestamp

_CATALOG_PATH = Path(__file__).with_name("catalog.yml")

_TENANT_TOKEN_ENDPOINT = "auth/v3/tenant_access_token/internal"
_WIKI_NODE_ENDPOINT = "wiki/v2/spaces/get_node"


class WikiNode(NamedTuple):
    """A Wiki node resolved to its embedded object token and Larksuite object type."""

    obj_token: str
    obj_type: str


@dataclass(frozen=True)
class ApiDef:
    """Config-driven definition of one Larksuite API, loaded from the catalog ``apis`` section."""

    reader: str
    obj_types: list[str]
    token_field: str
    primary_key: Union[str, list[str]]
    cursor_base_path: Optional[str] = None
    cursor_endpoint_path: Optional[str] = None
    cursor_query_params: dict[str, Any] = field(default_factory=dict)
    cursor_data_selector: str = "data.items"
    cursor_obj_token_column: Optional[str] = None
    sheet_values_path: Optional[str] = None
    sheet_row_json_column: str = "data"


@dataclass(frozen=True)
class ResourceSpec:
    """One Larksuite object to ingest, declared in the catalog ``resources`` section."""

    api: str
    resource_name: str
    wiki_token: Optional[str] = None
    app_token: Optional[str] = None
    table_id: Optional[str] = None
    spreadsheet_token: Optional[str] = None
    document_id: Optional[str] = None
    sheet_id: Optional[str] = None
    primary_key: Optional[Union[str, list[str]]] = None


def get_tenant_access_token(base_url: str, app_id: str, app_secret: str) -> str:
    """Exchange Larksuite application credentials for a short-lived tenant access token."""
    response = requests.post(
        f"{base_url}/{_TENANT_TOKEN_ENDPOINT}",
        json={"app_id": app_id, "app_secret": app_secret},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != 0:
        raise RuntimeError(f"Larksuite tenant_access_token request failed: {payload}")
    return payload["tenant_access_token"]


def resolve_wiki_node(base_url: str, access_token: str, wiki_token: str) -> WikiNode:
    """Resolve a Larksuite Wiki node to its embedded object token and type."""
    response = requests.get(
        f"{base_url}/{_WIKI_NODE_ENDPOINT}",
        headers={"Authorization": f"Bearer {access_token}"},
        params={"token": wiki_token, "obj_type": "wiki"},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != 0:
        raise RuntimeError(f"Larksuite wiki get_node request failed: {payload}")
    node = payload["data"]["node"]
    return WikiNode(obj_token=node["obj_token"], obj_type=node["obj_type"])


def _render_path_template(template: str, spec: ResourceSpec, obj_token: str) -> str:
    """Fill a ``str.format`` path template from the spec's token fields, raising if any is unset."""
    context = {
        "obj_token": obj_token,
        "table_id": spec.table_id,
        "document_id": spec.document_id,
        "spreadsheet_token": spec.spreadsheet_token,
        "app_token": spec.app_token,
    }
    try:
        return template.format(**{key: value for key, value in context.items() if value is not None})
    except KeyError as missing:
        raise ValueError(
            f"Resource {spec.resource_name!r} (api {spec.api!r}) is missing field "
            f"{missing.args[0]!r} required by template {template!r}"
        ) from None


def _build_cursor_resource(
    spec: ResourceSpec, api_def: ApiDef, base_url: str, access_token: str, obj_token: str
) -> DltResource:
    """Build a merge resource for any ``page_token``-paginated list endpoint."""
    
    run_timestamp = sync_timestamp()
    extra_columns = (
        {api_def.cursor_obj_token_column: obj_token} if api_def.cursor_obj_token_column else {}
    )
    config: RESTAPIConfig = {
        "client": {
            "base_url": f"{base_url}/{_render_path_template(api_def.cursor_base_path, spec, obj_token)}/",
            "headers": {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
        },
        "resources": [
            {
                "name": spec.resource_name,
                "primary_key": spec.primary_key or api_def.primary_key,
                "write_disposition": "merge",
                "endpoint": {
                    "path": _render_path_template(api_def.cursor_endpoint_path, spec, obj_token),
                    "params": dict(api_def.cursor_query_params),
                    "data_selector": api_def.cursor_data_selector,
                    "paginator": JSONResponseCursorPaginator(
                        cursor_path="data.page_token", cursor_param="page_token"
                    ),
                },
            }
        ],
    }
    resource = rest_api_resources(config)[0]
    resource.add_map(lambda item: {**item, **extra_columns, RAW_UPDATED_AT_COLUMN: run_timestamp})
    return apply_raw_hints(resource)


def _build_sheet_resource(
    spec: ResourceSpec, api_def: ApiDef, base_url: str, access_token: str, obj_token: str
) -> DltResource:
    """Build a resource yielding one record per data row of a single sheet."""

    run_timestamp = sync_timestamp()
    headers = {"Authorization": f"Bearer {access_token}"}
    primary_key = spec.primary_key or api_def.primary_key
    values_url = (
        f"{base_url}/{api_def.sheet_values_path.format(obj_token=obj_token, sheet_id=spec.sheet_id)}"
    )

    @dlt.resource(name=spec.resource_name, primary_key=primary_key, write_disposition="merge")
    def _sheet() -> Iterator[dict]:
        """Yield each data row of the configured sheet as a header-keyed JSON record."""
        values = requests.get(values_url, headers=headers).json()
        if values.get("code") != 0:
            raise RuntimeError(
                f"Larksuite values_get failed for sheet {spec.sheet_id!r} in {obj_token!r}: {values}"
            )

        rows = values["data"]["valueRange"].get("values") or []
        if not rows:
            return

        header = [str(cell) for cell in rows[0]]
        for row_number, row in enumerate(rows[1:], start=1):
            yield {
                "spreadsheet_token": obj_token,
                "sheet_id": spec.sheet_id,
                "row_number": row_number,
                api_def.sheet_row_json_column: dict(zip(header, row)),
                RAW_UPDATED_AT_COLUMN: run_timestamp,
            }

    return apply_raw_hints(_sheet)


_READERS = {
    "cursor": _build_cursor_resource,
    "sheet_values": _build_sheet_resource,
}


def load_catalog(
    config_path: Path = _CATALOG_PATH,
) -> tuple[dict[str, ApiDef], tuple[ResourceSpec, ...]]:
    """Load and validate the api definitions and resource specs from YAML."""
    catalog = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    api_defs = {name: ApiDef(**definition) for name, definition in catalog["apis"].items()}
    for name, api_def in api_defs.items():
        if api_def.reader not in _READERS:
            raise ValueError(
                f"Api {name!r} uses unknown reader {api_def.reader!r}; "
                f"expected one of {sorted(_READERS)}"
            )

    specs = tuple(ResourceSpec(**entry) for entry in catalog["resources"])
    for spec in specs:
        if spec.api not in api_defs:
            raise ValueError(
                f"Resource {spec.resource_name!r} references unknown api {spec.api!r}; "
                f"expected one of {sorted(api_defs)}"
            )
        api_def = api_defs[spec.api]
        if not getattr(spec, api_def.token_field) and not spec.wiki_token:
            raise ValueError(
                f"Resource {spec.resource_name!r} needs either {api_def.token_field!r} "
                f"or wiki_token"
            )
        if api_def.reader == "sheet_values" and not spec.sheet_id:
            raise ValueError(
                f"Resource {spec.resource_name!r} (api {spec.api!r}) requires a sheet_id"
            )
    return api_defs, specs


API_DEFS, RESOURCE_SPECS = load_catalog()

_API_TREE_SEGMENTS = {"bitable": "base", "sheet": "sheets", "doc": "document"}
_SPEC_BY_RESOURCE_NAME = {spec.resource_name: spec for spec in RESOURCE_SPECS}


def larksuite_resource_asset_path(resource_name: str) -> tuple[str, ...]:
    """Return the api-grouped Dagster asset key path ``(ingestion, larksuite, <segment>, resource_name)``."""
    spec = _SPEC_BY_RESOURCE_NAME[resource_name]
    segment = _API_TREE_SEGMENTS.get(spec.api, spec.api)
    return ("ingestion", "larksuite", segment, resource_name)


def _resolve_obj_token(
    spec: ResourceSpec, api_def: ApiDef, node_by_wiki: dict[str, WikiNode]
) -> str:
    """Resolve a spec's object token from a direct field or its Wiki node."""
    direct = getattr(spec, api_def.token_field)
    if direct:
        return direct
    node = node_by_wiki[spec.wiki_token]
    if node.obj_type and node.obj_type not in api_def.obj_types:
        raise RuntimeError(
            f"Wiki node {spec.wiki_token!r} resolves to obj_type {node.obj_type!r}, "
            f"incompatible with api {spec.api!r} for resource {spec.resource_name!r}"
        )
    return node.obj_token


def build_catalog_resources(
    base_url: str,
    access_token: str,
    *,
    resolve_tokens: bool = True,
) -> tuple[DltResource, ...]:
    """Build every catalog resource via the generic, config-driven readers."""
    node_by_wiki: dict[str, WikiNode] = {}
    if resolve_tokens:
        for spec in RESOURCE_SPECS:
            api_def = API_DEFS[spec.api]
            if not getattr(spec, api_def.token_field) and spec.wiki_token not in node_by_wiki:
                node_by_wiki[spec.wiki_token] = resolve_wiki_node(
                    base_url, access_token, spec.wiki_token
                )

    resources = []
    for spec in RESOURCE_SPECS:
        api_def = API_DEFS[spec.api]
        if resolve_tokens:
            obj_token = _resolve_obj_token(spec, api_def, node_by_wiki)
        else:
            obj_token = getattr(spec, api_def.token_field) or access_token
        resources.append(_READERS[api_def.reader](spec, api_def, base_url, access_token, obj_token))
    return tuple(resources)


__all__ = [
    "API_DEFS",
    "RESOURCE_SPECS",
    "ApiDef",
    "ResourceSpec",
    "WikiNode",
    "build_catalog_resources",
    "get_tenant_access_token",
    "larksuite_resource_asset_path",
    "load_catalog",
    "resolve_wiki_node",
]
