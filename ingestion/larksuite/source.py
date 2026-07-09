from __future__ import annotations

from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from .catalog import build_catalog_resources, get_tenant_access_token

DEFAULT_LARKSUITE_BASE_URL = "https://open.larksuite.com/open-apis"


@dlt.source(name="larksuite")
def larksuite_source(
    base_url: str = dlt.config.value,
    app_id: str = dlt.secrets.value,
    app_secret: str = dlt.secrets.value,
    access_token: Optional[str] = None,
) -> tuple[DltResource, ...]:
    """Build the Larksuite source across every object declared in the YAML catalog."""
    if access_token is None:
        access_token = get_tenant_access_token(base_url, app_id, app_secret)
        return build_catalog_resources(base_url, access_token, resolve_tokens=True)
    return build_catalog_resources(base_url, access_token, resolve_tokens=False)


def build_larksuite_source(
    *,
    base_url: Optional[str] = None,
    app_id: Optional[str] = None,
    app_secret: Optional[str] = None,
    access_token: Optional[str] = None,
):
    """Helper for creating a Larksuite source with optional explicit overrides."""
    source_kwargs: dict = {}
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if app_id is not None:
        source_kwargs["app_id"] = app_id
    if app_secret is not None:
        source_kwargs["app_secret"] = app_secret
    if access_token is not None:
        source_kwargs["access_token"] = access_token
    return larksuite_source(**source_kwargs)


__all__ = [
    "DEFAULT_LARKSUITE_BASE_URL",
    "build_larksuite_source",
]
