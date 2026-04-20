from dagster_dlt import DagsterDltResource

def get_dlt_resource() -> DagsterDltResource:
    """Get the Dagster dlt resource."""
    return DagsterDltResource()


__all__ = ["get_dlt_resource"]
