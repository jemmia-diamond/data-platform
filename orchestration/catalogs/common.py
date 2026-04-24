from __future__ import annotations

from dataclasses import dataclass

from ..tags import build_dagster_tags


AssetPath = tuple[str, ...]


@dataclass(frozen=True)
class ExecutionUnitSpec:
    layer: str
    tool: str
    system: str
    unit: str
    asset_paths: tuple[AssetPath, ...]
    description: str
    cadence: str
    name_segments: tuple[str, ...] = ()
    cron_schedule: str | None = None
    schedule_token: str | None = None
    schedule_description: str | None = None

    @property
    def resolved_name_segments(self) -> tuple[str, ...]:
        return self.name_segments or (self.system,)

    @property
    def dagster_tags(self) -> dict[str, str]:
        return build_dagster_tags(
            layer=self.layer,
            tool=self.tool,
            system=self.system,
            unit=self.unit,
            cadence=self.cadence,
        )

    @property
    def job_name(self) -> str:
        return "__".join((self.layer, *self.resolved_name_segments, self.unit, "job"))

    @property
    def has_schedule(self) -> bool:
        return self.cron_schedule is not None

    @property
    def schedule_name(self) -> str:
        if not self.has_schedule:
            raise ValueError(f"Execution unit {self.unit} does not define a schedule")
        token = self.schedule_token or self.cadence
        return "__".join(
            (self.layer, *self.resolved_name_segments, self.unit, token, "schedule")
        )


def validate_execution_units(specs: tuple[ExecutionUnitSpec, ...]) -> tuple[ExecutionUnitSpec, ...]:
    seen_job_names: set[str] = set()
    seen_schedule_names: set[str] = set()
    seen_asset_paths: set[AssetPath] = set()

    for spec in specs:
        if not spec.asset_paths:
            raise ValueError(f"Execution unit {spec.unit} must include at least one asset path")
        if spec.name_segments and any(not segment for segment in spec.name_segments):
            raise ValueError(f"Execution unit {spec.unit} contains an empty name segment")
        if spec.cadence == "manual" and spec.has_schedule:
            raise ValueError(f"Manual execution unit {spec.unit} cannot define a schedule")
        if not spec.has_schedule and (
            spec.schedule_token is not None or spec.schedule_description is not None
        ):
            raise ValueError(
                f"Execution unit {spec.unit} cannot define schedule metadata without a schedule"
            )

        if spec.job_name in seen_job_names:
            raise ValueError(f"Duplicate job name: {spec.job_name}")
        seen_job_names.add(spec.job_name)

        if spec.has_schedule:
            if spec.schedule_name in seen_schedule_names:
                raise ValueError(f"Duplicate schedule name: {spec.schedule_name}")
            seen_schedule_names.add(spec.schedule_name)

        for asset_path in spec.asset_paths:
            if asset_path in seen_asset_paths:
                raise ValueError(f"Asset path assigned to multiple execution units: {asset_path}")
            seen_asset_paths.add(asset_path)

    return specs


__all__ = ["AssetPath", "ExecutionUnitSpec", "validate_execution_units"]
