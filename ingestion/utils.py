from __future__ import annotations

import os

import psycopg2

_DEFAULT_FALLBACK = "2024-01-01T00:00:00+00:00"


def get_last_sync_ts(
    schema: str,
    table: str,
    column: str = "_db_updated_at",
    fallback: str = _DEFAULT_FALLBACK,
) -> str:
    """Return ISO timestamp of MAX(column) from the destination table.

    Falls back to `fallback` when the table doesn't exist yet or has no rows.
    Reads DB credentials from DESTINATION__POSTGRES__CREDENTIALS__* env vars.
    """
    try:
        conn = psycopg2.connect(
            host=os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__HOST"),
            port=int(os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__PORT")),
            dbname=os.environ["DESTINATION__POSTGRES__CREDENTIALS__DATABASE"],
            user=os.environ["DESTINATION__POSTGRES__CREDENTIALS__USERNAME"],
            password=os.environ["DESTINATION__POSTGRES__CREDENTIALS__PASSWORD"],
            connect_timeout=int(os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__CONNECT_TIMEOUT")),
        )
        with conn, conn.cursor() as cur:
            cur.execute(f'SELECT MAX("{column}") FROM "{schema}"."{table}"')
            result = cur.fetchone()[0]
        if result is not None:
            return result.isoformat()
    except Exception:
        pass
    return fallback


__all__ = ["get_last_sync_ts"]
