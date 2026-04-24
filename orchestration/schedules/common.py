from __future__ import annotations

from dagster import ScheduleDefinition

from ..catalogs.common import ExecutionUnitSpec


def build_schedule_definition(spec: ExecutionUnitSpec, job):
    if not spec.has_schedule or spec.cron_schedule is None:
        raise ValueError(f"Execution unit {spec.unit} does not define a schedule")

    return ScheduleDefinition(
        name=spec.schedule_name,
        job=job,
        cron_schedule=spec.cron_schedule,
        description=spec.schedule_description or spec.description,
        tags=spec.dagster_tags,
    )


def build_schedules_by_name(specs: tuple[ExecutionUnitSpec, ...], jobs_by_name: dict[str, object]) -> dict[str, ScheduleDefinition]:
    schedules: dict[str, ScheduleDefinition] = {}
    for spec in specs:
        if not spec.has_schedule:
            continue
        schedules[spec.schedule_name] = build_schedule_definition(
            spec,
            jobs_by_name[spec.job_name],
        )
    return schedules


__all__ = ["build_schedule_definition", "build_schedules_by_name"]
