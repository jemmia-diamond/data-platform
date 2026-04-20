from pathlib import Path

from .dbt import get_dbt_resource
from .dlt import get_dlt_resource


def all_resources(dbt_project_dir: Path, target: str = "dev") -> dict:
    return {
        "dbt": get_dbt_resource(dbt_project_dir, target=target),
        "dlt": get_dlt_resource(),
    }


__all__ = ["all_resources", "get_dbt_resource", "get_dlt_resource"]
