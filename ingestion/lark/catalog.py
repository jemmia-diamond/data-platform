from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterator, NamedTuple, Optional, Union

import dlt
import yaml
from dlt.common import logger
from dlt.extract.resource import DltResource
from dlt.sources.helpers import requests
from dlt.sources.helpers.rest_client.paginators import JSONResponseCursorPaginator
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

from ingestion.common import RAW_UPDATED_AT_COLUMN, apply_raw_hints, sync_timestamp

_CATALOG_PATH = Path(__file__).with_name("catalog.yml")

_TENANT_TOKEN_ENDPOINT = "auth/v3/tenant_access_token/internal"
_WIKI_NODE_ENDPOINT = "wiki/v2/spaces/get_node"


class WikiNode(NamedTuple):
    """A resolved Lark Wiki node.

    Attributes:
        obj_token: Token of the embedded object (Bitable ``app_token``,
            spreadsheet token, or Docx ``document_id`` depending on ``obj_type``).
        obj_type: Lark object type of the node (e.g. ``bitable``, ``sheet``, ``docx``).
    """

    obj_token: str
    obj_type: str


@dataclass(frozen=True)
class ApiDef:
    """Reusable, config-driven definition of one Lark API (shared by all resources).

    Loaded from the ``apis`` section of the YAML catalog so endpoint shapes live
    in config, not code.

    Attributes:
        reader: Which builder to use — ``cursor`` (page_token REST list) or
            ``sheet_values`` (whole-spreadsheet dump).
        obj_types: Wiki node ``obj_type`` values compatible with this api.
        token_field: The ``ResourceSpec`` field holding a direct object token.
        primary_key: Default merge key for resources of this api.
        base_path: ``cursor``: client base path template (``{...}`` placeholders).
        path: ``cursor``: endpoint path template relative to ``base_path``.
        params: ``cursor``: query parameters sent on every request.
        data_selector: ``cursor``: JSONPath to the record list in the response.
        token_column: ``cursor``: optional constant column stamped with obj_token.
        meta_path: ``sheet_values``: path template listing the sheets.
        values_path: ``sheet_values``: path template reading one sheet's values.
        row_column: ``sheet_values``: column name holding each raw row array.
    """

    reader: str
    obj_types: list[str]
    token_field: str
    primary_key: Union[str, list[str]]
    base_path: Optional[str] = None
    path: Optional[str] = None
    params: dict[str, Any] = field(default_factory=dict)
    data_selector: str = "data.items"
    token_column: Optional[str] = None
    meta_path: Optional[str] = None
    values_path: Optional[str] = None
    row_column: str = "data"


@dataclass(frozen=True)
class ResourceSpec:
    """Declarative specification for one Lark object to ingest.

    Attributes:
        api: Key into the ``apis`` catalog section (e.g. ``bitable`` / ``sheet`` / ``doc``).
        resource_name: Destination table name (``raw_lark.<resource_name>``).
        wiki_token: Wiki node token embedding the object; resolved to a token.
        app_token: Direct Bitable app token (alternative to ``wiki_token``).
        table_id: Bitable table id.
        spreadsheet_token: Direct spreadsheet token (alternative to ``wiki_token``).
        document_id: Direct Docx document id (alternative to ``wiki_token``).
        primary_key: Optional merge key override (else the api default applies).
    """

    api: str
    resource_name: str
    wiki_token: Optional[str] = None
    app_token: Optional[str] = None
    table_id: Optional[str] = None
    spreadsheet_token: Optional[str] = None
    document_id: Optional[str] = None
    primary_key: Optional[Union[str, list[str]]] = None


def get_tenant_access_token(base_url: str, app_id: str, app_secret: str) -> str:
    """Exchange Lark application credentials for a tenant access token.

    Args:
        base_url: Lark open-apis base URL.
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


def resolve_wiki_node(base_url: str, access_token: str, wiki_token: str) -> WikiNode:
    """Resolve a Lark Wiki node to its embedded object token and type."""
    response = requests.get(
        f"{base_url}/{_WIKI_NODE_ENDPOINT}",
        headers={"Authorization": f"Bearer {access_token}"},
        params={"token": wiki_token, "obj_type": "wiki"},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != 0:
        raise RuntimeError(f"Lark wiki get_node request failed: {payload}")
    node = payload["data"]["node"]
    return WikiNode(obj_token=node["obj_token"], obj_type=node["obj_type"])


def _render(template: str, spec: ResourceSpec, obj_token: str) -> str:
    """Render a path template from a spec's token fields.

    Args:
        template: A ``str.format`` template (e.g. ``tables/{table_id}/records``).
        spec: The resource specification providing placeholder values.
        obj_token: The resolved object token available as ``{obj_token}``.

    Returns:
        The rendered path.

    Raises:
        ValueError: If the template references a field that the spec leaves unset.
    """
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
    extra_columns = {api_def.token_column: obj_token} if api_def.token_column else {}
    config: RESTAPIConfig = {
        "client": {
            "base_url": f"{base_url}/{_render(api_def.base_path, spec, obj_token)}/",
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
                    "path": _render(api_def.path, spec, obj_token),
                    "params": dict(api_def.params),
                    "data_selector": api_def.data_selector,
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
    """Build a resource dumping every row of every sheet in a spreadsheet."""

    run_timestamp = sync_timestamp()
    headers = {"Authorization": f"Bearer {access_token}"}
    primary_key = spec.primary_key or api_def.primary_key
    meta_url = f"{base_url}/{api_def.meta_path.format(obj_token=obj_token)}"

    @dlt.resource(name=spec.resource_name, primary_key=primary_key, write_disposition="merge")
    def _spreadsheet() -> Iterator[dict]:
        """Yield every row across all sheets of the spreadsheet."""
        meta = requests.get(meta_url, headers=headers).json()
        if meta.get("code") != 0:
            raise RuntimeError(f"Lark sheets query failed: {meta}")

        for sheet in meta["data"]["sheets"]:
            sheet_id = sheet["sheet_id"]
            values_url = f"{base_url}/{api_def.values_path.format(obj_token=obj_token, sheet_id=sheet_id)}"
            values = requests.get(values_url, headers=headers).json()
            if values.get("code") != 0:
                logger.warning(
                    "Skipping sheet %r (%r) in spreadsheet %r: values_get returned %s",
                    sheet_id,
                    sheet.get("title"),
                    obj_token,
                    values,
                )
                continue

            rows = values["data"]["valueRange"].get("values") or []
            for row_number, row in enumerate(rows, start=1):
                yield {
                    "spreadsheet_token": obj_token,
                    "sheet_id": sheet_id,
                    "sheet_title": sheet.get("title"),
                    "row_number": row_number,
                    api_def.row_column: row,
                    RAW_UPDATED_AT_COLUMN: run_timestamp,
                }

    return apply_raw_hints(_spreadsheet)


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
    return api_defs, specs


API_DEFS, RESOURCE_SPECS = load_catalog()

_API_TREE_SEGMENTS = {"bitable": "base", "sheet": "sheets", "doc": "document"}
_SPEC_BY_RESOURCE_NAME = {spec.resource_name: spec for spec in RESOURCE_SPECS}


def lark_resource_asset_path(resource_name: str) -> tuple[str, ...]:
    """Return the object-type-grouped Dagster asset key path for a Lark resource.

    Groups resources under a segment derived from their catalog ``api`` so the
    Dagster asset tree reads ``ingestion / lark / <base|sheets|document> / <resource>``.

    Args:
        resource_name: The dlt resource (and destination table) name.

    Returns:
        The asset key path ``("ingestion", "lark", <segment>, resource_name)``.

    Raises:
        KeyError: If the resource name is not declared in the catalog.
    """
    spec = _SPEC_BY_RESOURCE_NAME[resource_name]
    segment = _API_TREE_SEGMENTS.get(spec.api, spec.api)
    return ("ingestion", "lark", segment, resource_name)


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
    "lark_resource_asset_path",
    "load_catalog",
    "resolve_wiki_node",
]
