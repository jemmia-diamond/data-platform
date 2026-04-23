def build_dagster_tags(
    *,
    layer: str,
    tool: str,
    system: str,
    family: str,
    cadence: str,
) -> dict[str, str]:
    return {
        "layer": layer,
        "tool": tool,
        "system": system,
        "family": family,
        "cadence": cadence,
    }


__all__ = ["build_dagster_tags"]
