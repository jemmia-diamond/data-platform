"""Daily end-of-day snapshot helper for merge-only Haravan raw tables.

dlt merge resources (``write_disposition="merge"``) only ever hold the latest
known state per key — no history. ``snapshot_table`` copies any such table
in ``raw_haravan`` once a day into a ``<table>_snapshot`` sibling, stamping
each row with ``snapshot_date`` so history can be queried later. Re-running
on the same day upserts (never duplicates) that day's rows.

To snapshot a new Haravan table, do NOT copy this file — call
``snapshot_table`` again with the new table name and its merge key, e.g.:

    snapshot_table(conn, source_table="orders", key_columns=("id",))
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any

SCHEMA_NAME = "raw_haravan"


def _source_columns(cur, source_table: str) -> list[str]:
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
        """,
        (SCHEMA_NAME, source_table),
    )
    columns = [row[0] for row in cur.fetchall()]
    if not columns:
        raise RuntimeError(
            f"{SCHEMA_NAME}.{source_table} has no columns — has Haravan {source_table} "
            "ingestion run at least once yet?"
        )
    return columns


def _ensure_snapshot_table(cur, source_table: str, snapshot_table: str, key_columns: tuple[str, ...]) -> None:
    cur.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {SCHEMA_NAME}.{snapshot_table} (
            LIKE {SCHEMA_NAME}.{source_table} INCLUDING DEFAULTS,
            snapshot_date date NOT NULL
        )
        """
    )
    cur.execute(
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = '{SCHEMA_NAME}.{snapshot_table}'::regclass
                AND contype = 'p'
            ) THEN
                ALTER TABLE {SCHEMA_NAME}.{snapshot_table}
                ADD CONSTRAINT {snapshot_table}_pkey
                PRIMARY KEY ({", ".join(key_columns)}, snapshot_date);
            END IF;
        END $$;
        """
    )


def snapshot_table(
    conn,
    *,
    source_table: str,
    key_columns: tuple[str, ...],
    snapshot_table: str | None = None,
    snapshot_date: date | None = None,
) -> dict[str, Any]:
    """Copy raw_haravan.<source_table> into raw_haravan.<source_table>_snapshot."""
    target_table = snapshot_table or f"{source_table}_snapshot"
    resolved_date = snapshot_date or datetime.now(timezone.utc).date()

    with conn.cursor() as cur:
        columns = _source_columns(cur, source_table)
        _ensure_snapshot_table(cur, source_table, target_table, key_columns)

        col_list = ", ".join(columns)
        update_columns = [c for c in columns if c not in key_columns]
        set_clause = ", ".join(f"{c} = EXCLUDED.{c}" for c in update_columns)

        cur.execute(
            f"""
            INSERT INTO {SCHEMA_NAME}.{target_table} ({col_list}, snapshot_date)
            SELECT {col_list}, %s FROM {SCHEMA_NAME}.{source_table}
            ON CONFLICT ({", ".join(key_columns)}, snapshot_date) DO UPDATE SET
                {set_clause}
            """,
            (resolved_date,),
        )
        rows = cur.rowcount

    conn.commit()
    return {"rows": rows, "snapshot_date": resolved_date.isoformat(), "table": target_table}


__all__ = ["snapshot_table"]
