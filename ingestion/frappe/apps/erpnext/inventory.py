from __future__ import annotations

"""
Inventory-related ERPNext resources.

Put complex "fan-out" logic here. Example patterns:
- Call API A to fetch IDs
- For each ID call API B to fetch details
- Join/mix extra data from API C

We keep this separate from `common.py` to avoid `if/else` bloat in the generic builder.
"""


__all__ = []

