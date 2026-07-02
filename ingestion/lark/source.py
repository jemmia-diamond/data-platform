from __future__ import annotations

from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from .catalog import build_catalog_resources, get_tenant_access_token

DEFAULT_LARK_BASE_URL = "https://open.larksuite.com/open-apis"


@dlt.source(name="lark")
def lark_source(
    base_url: str = dlt.config.value,
    app_id: str = dlt.secrets.value,
    app_secret: str = dlt.secrets.value,
    access_token: Optional[str] = None,
) -> tuple[DltResource, ...]:
    """Build the Lark source across every object declared in the YAML catalog.

    Each catalog entry declares its ``api`` (``bitable`` / ``sheet`` / ``doc``)
    and how to locate the object (a direct token or a ``wiki_token``). Passing
    ``access_token`` skips authentication and Wiki resolution, letting the source
    be instantiated with placeholders for offline asset discovery.

    Args:
        base_url: Lark open-apis base URL, resolved from config.
        app_id: Lark custom app identifier, resolved from secrets.
        app_secret: Lark custom app secret, resolved from secrets.
        access_token: Optional tenant access token; when supplied, no network
            calls are made during source construction.

    Returns:
        A tuple of dlt resources, one per catalog entry.
    """
    if access_token is None:
        access_token = get_tenant_access_token(base_url, app_id, app_secret)
        return build_catalog_resources(base_url, access_token, resolve_tokens=True)
    return build_catalog_resources(base_url, access_token, resolve_tokens=False)


def build_lark_source(
    *,
    base_url: Optional[str] = None,
    app_id: Optional[str] = None,
    app_secret: Optional[str] = None,
    access_token: Optional[str] = None,
):
    """Helper for creating a Lark source with optional explicit overrides.

    Args:
        base_url: Override for the Lark open-apis base URL.
        app_id: Override for the Lark app identifier.
        app_secret: Override for the Lark app secret.
        access_token: Override for the tenant access token; skips all network calls.

    Returns:
        A configured Lark dlt source.
    """
    source_kwargs: dict = {}
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if app_id is not None:
        source_kwargs["app_id"] = app_id
    if app_secret is not None:
        source_kwargs["app_secret"] = app_secret
    if access_token is not None:
        source_kwargs["access_token"] = access_token
    return lark_source(**source_kwargs)


__all__ = [
    "DEFAULT_LARK_BASE_URL",
    "build_lark_source",
]
