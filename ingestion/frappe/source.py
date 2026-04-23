from __future__ import annotations

from typing import Optional

import dlt

from .apps.erpnext import build_erpnext_resources

DEFAULT_FRAPPE_BASE_URL = "https://example.com"
# Keep as string so it can be passed directly into filters if needed.
DEFAULT_START_DATE = "2026-04-20"

@dlt.source(name="frappe")
def frappe_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    base_url: str = dlt.config.value,
    api_key: str = dlt.secrets.value,
    api_secret: str = dlt.secrets.value,
    api_auth_scheme: str = "token",
    verify: bool = True,
    fetch_full_docs: bool = True,
):
    """Build the Frappe source and let dlt resolve config from env vars."""
    return build_erpnext_resources(
        base_url=base_url,
        api_key=api_key,
        api_secret=api_secret,
        api_auth_scheme=api_auth_scheme,
        start_date=start_date,
        end_date=end_date,
        verify=verify,
        fetch_full_docs=fetch_full_docs,
    )


def build_frappe_source(
    start_date: str = DEFAULT_START_DATE,
    end_date: Optional[str] = None,
    *,
    base_url: Optional[str] = None,
    api_key: Optional[str] = None,
    api_secret: Optional[str] = None,
    api_auth_scheme: Optional[str] = None,
    verify: Optional[bool] = None,
    fetch_full_docs: Optional[bool] = None,
):
    """Helper for creating a Frappe source with optional explicit overrides."""
    source_kwargs: dict = {
        "start_date": start_date,
        "end_date": end_date,
    }
    if base_url is not None:
        source_kwargs["base_url"] = base_url
    if api_key is not None:
        source_kwargs["api_key"] = api_key
    if api_secret is not None:
        source_kwargs["api_secret"] = api_secret
    if api_auth_scheme is not None:
        source_kwargs["api_auth_scheme"] = api_auth_scheme
    if verify is not None:
        source_kwargs["verify"] = verify
    if fetch_full_docs is not None:
        source_kwargs["fetch_full_docs"] = fetch_full_docs
    return frappe_source(**source_kwargs)


__all__ = ["DEFAULT_FRAPPE_BASE_URL", "DEFAULT_START_DATE", "build_frappe_source"]
