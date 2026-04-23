def build_schedule_tags(
    *,
    layer: str,
    cadence: str,
    source: str,
    group: str,
) -> dict[str, str]:
    return {
        "layer": layer,
        "source": source,
        "cadence": cadence,
        "group": group,
    }


__all__ = ["build_schedule_tags"]
