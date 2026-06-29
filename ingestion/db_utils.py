"""Shared PostgreSQL destination utilities for all ingestion sources."""
from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


def get_max_updated_at(schema: str, table: str, column: str = "updated_at") -> Optional[datetime]:
    """Return the maximum value of a timestamp column from a destination table.

    Uses DESTINATION__POSTGRES__CREDENTIALS__* environment variables so no extra
    config is required beyond what dlt already expects.

    Args:
        schema: PostgreSQL schema name (e.g. ``"raw_pancake"``).
        table: Table name within that schema (e.g. ``"conversations"``).
        column: Timestamp column to aggregate (defaults to ``"updated_at"``).

    Returns:
        Aware UTC datetime of the maximum value, or None if the table is empty,
        does not exist, or the DB is unreachable.
    """
    try:
        import psycopg2
    except ImportError:
        logger.warning("psycopg2 not installed — cannot query destination DB.")
        return None

    try:
        conn = psycopg2.connect(
            host=os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__HOST", "localhost"),
            port=int(os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__PORT", "5432")),
            dbname=os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__DATABASE", ""),
            user=os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__USERNAME", ""),
            password=os.environ.get("DESTINATION__POSTGRES__CREDENTIALS__PASSWORD", ""),
            connect_timeout=10,
        )
        try:
            with conn.cursor() as cur:
                cur.execute(f"SELECT MAX({column}) FROM {schema}.{table}")
                row = cur.fetchone()
                if row and row[0] is not None:
                    ts: datetime = row[0]
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    return ts.astimezone(timezone.utc)
                return None
        finally:
            conn.close()
    except Exception as exc:
        logger.warning("Could not query %s.%s MAX(%s): %s.", schema, table, column, exc)
        return None


__all__ = ["get_max_updated_at"]
