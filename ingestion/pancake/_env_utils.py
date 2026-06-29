"""Environment-based secret utilities for the Pancake ingestion module.

This module is a **temporary local solution** for loading secrets from environment
variables during development.  It will be replaced by Infisical secret management
before the pipeline runs in production, at which point this file can be removed and
all secret references updated to use the Infisical provider.
"""

from __future__ import annotations

import os

_PAT_ENV_PREFIX = "SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__"


def load_page_access_tokens_from_env() -> dict:
    """Read page access tokens from environment variables.

    Scans for env vars matching SOURCES__PANCAKE__PAGE_ACCESS_TOKENS__<page_id>
    and returns a mapping of page_id to token.

    Returns:
        Mapping of page_id (str) to page access token (str).
    """
    return {
        k[len(_PAT_ENV_PREFIX):]: v
        for k, v in os.environ.items()
        if k.startswith(_PAT_ENV_PREFIX) and v
    }


__all__ = ["load_page_access_tokens_from_env"]
