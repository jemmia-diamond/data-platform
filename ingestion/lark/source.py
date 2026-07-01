from __future__ import annotations

from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from .resources import (
    TABLE_SPECS,
    TableSpec,
    build_table_resource,
    get_tenant_access_token,
    resolve_wiki_app_token,
)

DEFAULT_LARK_BASE_URL = "https://open.larksuite.com/open-apis"


def _resolve_app_tokens(
    base_url: str,
    access_token: str,
    specs: tuple[TableSpec, ...],
) -> dict[str, str]:
    """Resolve each distinct Wiki token to its Bitable ``app_token`` exactly once.

    Args:
        base_url: Lark open-apis base URL.
        access_token: Tenant access token used as the bearer credential.
        specs: Table specifications whose Wiki tokens must be resolved.

    Returns:
        A mapping of ``wiki_token`` to its resolved Bitable ``app_token``.
    """
    app_token_by_wiki: dict[str, str] = {}
    for spec in specs:
        if spec.wiki_token not in app_token_by_wiki:
            app_token_by_wiki[spec.wiki_token] = resolve_wiki_app_token(
                base_url, access_token, spec.wiki_token
            )
    return app_token_by_wiki


@dlt.source(name="lark")
def lark_source(
    base_url: str = dlt.config.value,
    app_id: str = dlt.secrets.value,
    app_secret: str = dlt.secrets.value,
    access_token: Optional[str] = None,
) -> tuple[DltResource, ...]:
    """Build the Lark Bitable source for every configured table.

    Each table declares its own ``wiki_token`` in the YAML catalog, so tables
    from different Wiki spaces / Bases are supported. Authentication happens once
    and each distinct Wiki token is resolved to its ``app_token`` a single time.
    Passing ``access_token`` skips all network calls, letting the source be
    instantiated with placeholders for offline asset discovery.

    Args:
        base_url: Lark open-apis base URL, resolved from config.
        app_id: Lark custom app identifier, resolved from secrets.
        app_secret: Lark custom app secret, resolved from secrets.
        access_token: Optional tenant access token; when supplied, both the
            credential exchange and Wiki resolution are skipped.

    Returns:
        A tuple of dlt resources, one per Bitable table in ``TABLE_SPECS``.
    """
    if access_token is None:
        access_token = get_tenant_access_token(base_url, app_id, app_secret)
        app_token_by_wiki = _resolve_app_tokens(base_url, access_token, TABLE_SPECS)
    else:
        app_token_by_wiki = {spec.wiki_token: access_token for spec in TABLE_SPECS}

    return tuple(
        build_table_resource(
            spec=spec,
            base_url=base_url,
            access_token=access_token,
            app_token=app_token_by_wiki[spec.wiki_token],
        )
        for spec in TABLE_SPECS
    )


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
        access_token: Override for the tenant access token; skips all network
            calls (credential exchange and Wiki resolution).

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
