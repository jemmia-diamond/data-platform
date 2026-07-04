from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from .resources import DEFAULT_ENDPOINT_SPECS, EndpointSpec, build_snapshot_resource

DEFAULT_OPENFACET_BASE_URL = "https://data.openfacet.net"


@dlt.source(name="openfacet")
def openfacet_source(
    base_url: str = dlt.config.value,
    specs: tuple[EndpointSpec, ...] = DEFAULT_ENDPOINT_SPECS,
) -> tuple[DltResource, ...]:
    """Build the OpenFacet source as a tuple of eager, named snapshot resources.

    Each endpoint becomes its own ``raw_openfacet.<resource_name>_snapshots``
    table merged on ``snapshot_date`` (one row per published day).
    """
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    return tuple(build_snapshot_resource(spec, base_url, sync_timestamp) for spec in specs)


def build_openfacet_source(*, base_url: Optional[str] = None, specs: Optional[tuple[EndpointSpec, ...]] = None):
    """Helper for creating an OpenFacet source with optional explicit overrides.

    Resolves ``base_url`` from the environment (``SOURCES__OPENFACET__BASE_URL``)
    via dlt config when not provided explicitly, falling back to the public
    default so local/dev runs work without configuration.
    """
    return openfacet_source(
        base_url=base_url if base_url is not None else DEFAULT_OPENFACET_BASE_URL,
        specs=specs if specs is not None else DEFAULT_ENDPOINT_SPECS,
    )


__all__ = [
    "DEFAULT_OPENFACET_BASE_URL",
    "build_openfacet_source",
]
