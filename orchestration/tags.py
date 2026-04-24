def build_dagster_tags(
    *,
    layer: str,
    tool: str,
    system: str,
    unit: str,
    cadence: str,
) -> dict[str, str]:
    return {
        "layer": layer,
        "tool": tool,
        "system": system,
        "unit": unit,
        "cadence": cadence,
    }


__all__ = ["build_dagster_tags"]
