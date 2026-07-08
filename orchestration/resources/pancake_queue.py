from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

import psycopg2
from dagster import ConfigurableResource

_DSN_PREFIX = "DESTINATION__POSTGRES__CREDENTIALS__"
_REQUIRED_KEYS = ("HOST", "PORT", "DATABASE", "USERNAME", "PASSWORD")


class PancakeQueueResource(ConfigurableResource):
    """psycopg2 connection to the Postgres holding ``raw_pancake`` + the message queue.

    Reuses the same ``DESTINATION__POSTGRES__CREDENTIALS__*`` env vars as the dlt
    postgres destination, so the queue always lives in the database that dlt
    writes ``raw_pancake.messages`` into — no separate credentials to manage.
    """

    sslmode: str = "disable"

    @contextmanager
    def get_connection(self) -> Iterator[psycopg2.extensions.connection]:
        conn = psycopg2.connect(**self._dsn_kwargs())
        conn.autocommit = False
        try:
            yield conn
        finally:
            conn.close()

    def _dsn_kwargs(self) -> dict:
        creds = {key: os.environ.get(_DSN_PREFIX + key) for key in _REQUIRED_KEYS}
        missing = [key for key, value in creds.items() if not value]
        if missing:
            raise RuntimeError(
                "PancakeQueueResource is missing "
                f"DESTINATION__POSTGRES__CREDENTIALS__{'/'.join(missing)} "
                "(set it in .env and mirror it in docker-compose `dagster_code`)."
            )
        # Inherit SSL mode from dlt's DESTINATION__POSTGRES__CREDENTIALS__SSLMODE
        # if present, otherwise fall back to the resource default (disable).
        sslmode = os.environ.get(_DSN_PREFIX + "SSLMODE") or self.sslmode
        return {
            "host": creds["HOST"],
            "port": int(creds["PORT"]),
            "dbname": creds["DATABASE"],
            "user": creds["USERNAME"],
            "password": creds["PASSWORD"],
            "sslmode": sslmode,
        }


__all__ = ["PancakeQueueResource"]
